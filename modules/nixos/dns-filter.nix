{
  lib,
  settings,
  ...
}:

let
  cfg = settings.dns.filtering;
  allowlistSource = lib.concatStringsSep "\n" cfg.allowlist + "\n";
in
{
  assertions = lib.optionals cfg.enable [
    {
      assertion = lib.hasPrefix "https://" settings.dns.dohUrl;
      message = "settings.dns.dohUrl must use HTTPS while Blocky is enabled.";
    }
    {
      assertion = settings.dns.bootstrapIps != [ ];
      message = "settings.dns.bootstrapIps must not be empty while Blocky is enabled.";
    }
    {
      assertion =
        cfg.blocklistUrls != [ ]
        && lib.all (url: lib.hasPrefix "https://" url) cfg.blocklistUrls;
      message = "settings.dns.filtering.blocklistUrls must be non-empty HTTPS URLs.";
    }
  ];

  services.blocky = lib.mkIf cfg.enable {
    enable = true;
    enableConfigCheck = true;

    settings = {
      # Listen only on loopback and do not configure an HTTP/API listener. The
      # latter is especially important because Blocky's control API has no
      # built-in authentication.
      ports.dns = [
        "127.0.0.1:5353"
        "[::1]:5353"
      ];

      # Use one unfiltered provider and send each allowed query only once. DoH
      # on 443 is more compatible with restrictive networks than system DoT on
      # 853, while bootstrap IPs prevent a local resolver loop.
      upstreams = {
        init.strategy = "blocking";
        groups.default = [ settings.dns.dohUrl ];
        strategy = "strict";
        timeout = "5s";
      };
      bootstrapDns = [
        {
          upstream = settings.dns.dohUrl;
          ips = settings.dns.bootstrapIps;
        }
      ];

      blocking = {
        denylists.privacy = cfg.blocklistUrls;
        clientGroupsBlock.default = [ "privacy" ];

        # NXDOMAIN cannot accidentally send a browser to a synthetic blocking
        # address. A short negative TTL makes an allowlist correction take
        # effect quickly after a rebuild/restart.
        blockType = "nxDomain";
        blockTTL = "1m";

        # Do not hold DNS startup on a list download. Refresh daily; upstream
        # resolution remains usable if initial loading or a refresh fails.
        loading = {
          strategy = "fast";
          refreshPeriod = "24h";
          downloads = {
            timeout = "30s";
            attempts = 3;
            cooldown = "2s";
          };
        };
      }
      // lib.optionalAttrs (cfg.allowlist != [ ]) {
        allowlists.privacy = [ allowlistSource ];
      };

      # Retain only redacted operational warnings. Per-query logging and the
      # query database are disabled.
      log = {
        level = "warn";
        privacy = true;
      };
      queryLog.type = "none";
    };
  };

  # Keep resolved's upstream early-boot ordering: it runs before sysinit.target.
  # Ordering it after a regular service such as Blocky creates a boot cycle.
  # Blocky starts independently after networking; local DNS may briefly return
  # failure until it is ready. Bootstrap IPs avoid depending on resolved here.
  systemd.services.blocky.after = lib.mkIf cfg.enable [ "network-online.target" ];
}
