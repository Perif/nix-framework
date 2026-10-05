{ pkgs, ... }:

let
  fixturePython = pkgs.python3.withPackages (packages: [ packages.dnspython ]);
  fixtureCertificate =
    pkgs.runCommand "dns-boot-fixture-certificate"
      {
        nativeBuildInputs = [ pkgs.openssl ];
      }
      ''
        mkdir -p "$out"
        openssl req -x509 -newkey rsa:2048 -nodes -days 3650 \
          -keyout "$out/key.pem" -out "$out/cert.pem" \
          -subj "/CN=dns-fixture.test" \
          -addext "subjectAltName=DNS:dns-fixture.test"
      '';
  fixtureServer = pkgs.writeText "dns-boot-fixture.py" ''
    import base64
    import http.server
    import ssl
    import urllib.parse

    import dns.flags
    import dns.message
    import dns.rdatatype
    import dns.rrset


    class Handler(http.server.BaseHTTPRequestHandler):
        def reply(self, body, content_type):
            self.send_response(200)
            self.send_header("Content-Type", content_type)
            self.send_header("Content-Length", str(len(body)))
            self.end_headers()
            self.wfile.write(body)

        def do_GET(self):
            if self.path == "/health":
                self.reply(b"ready\n", "text/plain")
            elif self.path == "/denylist":
                self.reply(b"blocked.test\nallowlisted.test\n", "text/plain")
            elif self.path.startswith("/dns-query?"):
                query = urllib.parse.parse_qs(urllib.parse.urlsplit(self.path).query)["dns"][0]
                self.reply_dns(base64.urlsafe_b64decode(query + "=" * (-len(query) % 4)))
            else:
                self.send_error(404)

        def do_POST(self):
            if self.path != "/dns-query":
                self.send_error(404)
                return
            self.reply_dns(
                self.rfile.read(int(self.headers["Content-Length"]))
            )

        def reply_dns(self, wire):
            query = dns.message.from_wire(wire)
            response = dns.message.make_response(query)
            response.flags |= dns.flags.RA
            question = query.question[0]
            if question.rdtype == dns.rdatatype.A:
                # Blocky uses its bootstrap resolver for the normal DoH
                # upstream and denylist download host, independently of NSS.
                address = (
                    "127.0.0.1"
                    if str(question.name).lower() == "dns-fixture.test."
                    else "192.0.2.10"
                )
                response.answer.append(
                    dns.rrset.from_text(question.name, 1, "IN", "A", address)
                )
            self.reply(response.to_wire(), "application/dns-message")


    context = ssl.SSLContext(ssl.PROTOCOL_TLS_SERVER)
    context.load_cert_chain(
        "${fixtureCertificate}/cert.pem", "${fixtureCertificate}/key.pem"
    )
    server = http.server.ThreadingHTTPServer(("127.0.0.1", 8443), Handler)
    server.socket = context.wrap_socket(server.socket, server_side=True)
    server.serve_forever()
  '';
in
{
  name = "dns-boot";

  nodes.machine = {
    imports = [ ../modules/nixos/dns-filter.nix ];

    # Exercise production DNS routing and TLS without contacting an external
    # resolver or downloading live lists. No desktop or laptop hardware needed.
    _module.args.settings.dns = {
      dohUrl = "https://dns-fixture.test:8443/dns-query";
      bootstrapIps = [ "127.0.0.1" ];
      servers = [ "127.0.0.1#dns-fixture.test" ];
      filtering = {
        enable = true;
        blocklistUrls = [ "https://dns-fixture.test:8443/denylist" ];
        allowlist = [ "allowlisted.test" ];
      };
    };

    virtualisation.memorySize = 512;
    networking.hosts."127.0.0.1" = [ "dns-fixture.test" ];
    security.pki.certificateFiles = [ "${fixtureCertificate}/cert.pem" ];
    environment.systemPackages = [ pkgs.dnsutils ];

    systemd.services.dns-fixture = {
      wantedBy = [ "multi-user.target" ];
      serviceConfig = {
        ExecStart = "${fixturePython}/bin/python ${fixtureServer}";
        ExecStartPost = "${pkgs.curl}/bin/curl --fail --silent --retry 30 --retry-connrefused --retry-delay 1 --resolve dns-fixture.test:8443:127.0.0.1 --cacert ${fixtureCertificate}/cert.pem https://dns-fixture.test:8443/health";
      };
    };
    systemd.services.blocky = {
      requires = [ "dns-fixture.service" ];
      after = [ "dns-fixture.service" ];
    };
  };

  testScript = ''
    machine.start()
    machine.wait_for_unit("multi-user.target", timeout=120)
    machine.wait_for_unit("systemd-resolved.service", timeout=120)
    machine.wait_for_unit("blocky.service", timeout=120)

    with subtest("Resolved retains early boot ordering without a cycle"):
        ordering = machine.succeed(
            "systemctl show systemd-resolved.service --property=After --value"
        ).split()
        assert "blocky.service" not in ordering, ordering
        journal = machine.succeed("journalctl -b --no-pager").lower()
        assert "ordering cycle" not in journal, journal

    with subtest("System lookups traverse resolved and Blocky to the offline DoH fixture"):
        machine.wait_until_succeeds(
            "getent ahostsv4 allowed.test | grep -F 192.0.2.10", timeout=60
        )

    with subtest("Downloaded denylist blocks through the system resolver"):
        # Production list loading is asynchronous. Wait on Blocky directly
        # before testing resolved so its cache never contains an early answer.
        machine.wait_until_succeeds(
            "dig @127.0.0.1 -p 5353 blocked.test A +noall +comments "
            "| grep -F 'status: NXDOMAIN'", timeout=60
        )
        machine.succeed(
            "dig @127.0.0.53 blocked.test A +noall +comments "
            "| grep -F 'status: NXDOMAIN'"
        )
        machine.fail("getent ahostsv4 blocked.test")

    with subtest("Explicit allowlist takes priority over the denylist"):
        machine.succeed("getent ahostsv4 allowlisted.test | grep -F 192.0.2.10")

    with subtest("DNS recovers when Blocky restarts independently of resolved"):
        resolved_pid = machine.succeed(
            "systemctl show systemd-resolved.service --property=MainPID --value"
        ).strip()
        machine.succeed("systemctl restart blocky.service", "resolvectl flush-caches")
        machine.wait_for_unit("blocky.service", timeout=120)
        machine.wait_until_succeeds(
            "getent ahostsv4 after-restart.test | grep -F 192.0.2.10", timeout=60
        )
        assert resolved_pid == machine.succeed(
            "systemctl show systemd-resolved.service --property=MainPID --value"
        ).strip()
  '';
}
