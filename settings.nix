# Machine and user parameters.
#
# This is the only file that needs to change for installation-specific values.
# flake.nix passes it to every NixOS and Home Manager module as the `settings`
# argument.
{
  # networking.hostName and the flake output name:
  #   nixos-rebuild switch --flake .#<hostname>
  hostname = "framework-pro";

  # Regional settings used by the system, Plasma and console. Keep an explicit
  # IANA zone because GeoClue location detection is disabled for privacy. Change
  # this value and rebuild when travelling to a different time zone.
  timeZone = "America/Chicago";
  defaultLocale = "en_US.UTF-8";
  consoleKeyMap = "us";

  # Unfiltered encrypted DNS upstream. Blocky applies the local, reviewable
  # privacy and threat lists below; the provider itself does not impose a
  # category or threat blocklist. Firefox deliberately uses dohUrl directly as an
  # unfiltered recovery path, while system applications and Chromium-family
  # browsers use Blocky through systemd-resolved.
  #
  # Keeping all provider-specific values here makes a later provider change a
  # one-file edit. Each system resolver address includes the TLS server name
  # that systemd-resolved verifies.
  dns = {
    providerName = "Cloudflare 1.1.1.1 (unfiltered)";
    servers = [
      "1.1.1.1#one.one.one.one"
      "1.0.0.1#one.one.one.one"
      "2606:4700:4700::1111#one.one.one.one"
      "2606:4700:4700::1001#one.one.one.one"
    ];
    dohUrl = "https://cloudflare-dns.com/dns-query";

    # Blocky uses these addresses only to bootstrap the DoH hostname without
    # recursing through the system resolver that points back to Blocky.
    bootstrapIps = [
      "1.1.1.1"
      "1.0.0.1"
    ];

    filtering = {
      enable = true;

      # HaGeZi Normal provides broad everyday privacy blocking with a low
      # restriction risk. Full TIF adds broader threat coverage. Measure Blocky
      # memory during refresh; Mini is a reduced-coverage size fallback, not a
      # proven lower-false-positive tier. These wildcard forms target Blocky.
      blocklistUrls = [
        "https://raw.githubusercontent.com/hagezi/dns-blocklists/main/wildcard/normal.txt"
        "https://raw.githubusercontent.com/hagezi/dns-blocklists/main/wildcard/tif.txt"
      ];

      # Add only domain or wildcard lines, for example "example.com" or
      # "*.example.com". Allowlists override both denylists after a rebuild.
      allowlist = [ ];
    };
  };

  # Destructive Disko target. Replace this sentinel with the verified stable
  # path for the target drive; evaluation deliberately fails until then.
  diskDevice = "/dev/disk/by-id/REPLACE-WITH-YOUR-NVME-ID";

  user = {
    name = "py";
    description = "PY";

    # Leave both null for the safest installation path, then set the password
    # with `nixos-enter --root /mnt -c 'passwd <username>'` after nixos-install
    # and before rebooting. This keeps password material out of Git and the Nix
    # store.
    #
    # hashedPassword:  optional declarative hash from `mkpasswd -m yescrypt`.
    #                  It is not plaintext, but is still world-readable in the
    #                  Nix store and permits offline password guessing.
    # initialPassword: emergency-only plaintext for first user creation. It is
    #                  world-readable in /nix/store; change it immediately and
    #                  return this setting to null.
    #
    # users.mutableUsers stays at its default (true), so `passwd` keeps
    # working after installation either way.
    hashedPassword = null;
    initialPassword = null;

    # SSH public keys allowed to log in as this user. sshd is enabled only
    # when this list is non-empty; password authentication stays disabled.
    sshAuthorizedKeys = [ ];
  };

  features = {
    # QBZ builds from source and can be expensive during installation. Set
    # false for the initial install if needed, then true after the first boot.
    qbz = true;

    # Leave false for the initial installation. After the first boot, create
    # and verify local Secure Boot keys by following docs/INSTALL.md, then set
    # this to true before enabling Secure Boot in firmware.
    secureBoot = false;
  };

  git = {
    userName = "PY";
    userEmail = "py@example.invalid";
  };
}
