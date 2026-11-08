{
  lib,
  pkgs,
  settings,
  ...
}:

let
  user = settings.user;
  hasHashedPassword = user.hashedPassword != null;
  hasInitialPassword = user.initialPassword != null;
  captivePortalScript = pkgs.writeShellApplication {
    name = "captive-portal-mode";
    runtimeInputs = [ pkgs.coreutils pkgs.gawk pkgs.networkmanager pkgs.systemd ];
    text = ''
      set -euo pipefail

      state_dir=/run/captive-portal-mode
      state_file="$state_dir/state"

      active_wifi_device() {
        nmcli -t -f DEVICE,TYPE,STATE device status | awk -F: \
          '$2 == "wifi" && $3 == "connected" { print $1; exit }'
      }

      reconnect() {
        local device="$1"
        local connection="$2"
        nmcli connection down "$connection" ifname "$device" || true
        nmcli connection up "$connection" ifname "$device"
      }

      case "''${1:-}" in
        activate)
          device="$(active_wifi_device)"
          if [ -z "$device" ]; then
            echo "Connect to Wi-Fi first, then start captive-portal-mode." >&2
            exit 1
          fi

          connection="$(nmcli -g GENERAL.CONNECTION device show "$device")"
          if [ -z "$connection" ] || [ "$connection" = "--" ]; then
            echo "No active Wi-Fi connection profile found for $device." >&2
            exit 1
          fi

          ipv4_auto_dns="$(nmcli -g ipv4.ignore-auto-dns connection show "$connection")"
          ipv6_auto_dns="$(nmcli -g ipv6.ignore-auto-dns connection show "$connection")"
          install -d -m 700 "$state_dir"
          printf '%s\n%s\n%s\n%s\n' "$device" "$connection" "$ipv4_auto_dns" "$ipv6_auto_dns" >"$state_file"

          nmcli connection modify "$connection" \
            ipv4.ignore-auto-dns no ipv6.ignore-auto-dns no
          reconnect "$device" "$connection"
          # Prefer this link's DHCP DNS while the declarative resolver policy
          # is still loaded. The service stop action removes this runtime route.
          resolvectl domain "$device" '~.' || true
          ;;
        deactivate)
          [ -f "$state_file" ] || exit 0
          mapfile -t saved <"$state_file"
          device="''${saved[0]}"
          connection="''${saved[1]}"
          nmcli connection modify "$connection" \
            ipv4.ignore-auto-dns "''${saved[2]}" ipv6.ignore-auto-dns "''${saved[3]}"
          reconnect "$device" "$connection" || true
          resolvectl revert "$device" || true
          rm -rf "$state_dir"
          ;;
        *)
          echo "usage: captive-portal-mode activate|deactivate" >&2
          exit 64
          ;;
      esac
    '';
  };
in
{
  assertions = [
    {
      assertion = builtins.match "[a-z_][a-z0-9_-]{0,31}" user.name != null && user.name != "root";
      message = "settings.user.name must be a non-root Linux username (lowercase letters, digits, underscore or hyphen).";
    }
    {
      assertion = settings.timeZone != null;
      message = "settings.nix: run nix run .#detect-timezone during installation, or set timeZone to an explicit IANA zone.";
    }
    {
      assertion = !(hasHashedPassword && hasInitialPassword);
      message = ''
        settings.nix: set at most one of user.hashedPassword or
        user.initialPassword. Prefer leaving both null and setting the password
        with nixos-enter after installation, as documented in docs/00-install.md.
      '';
    }
    {
      assertion = user.initialPassword != "changeme";
      message = ''
        settings.nix: replace the unsafe "changeme" initial password.
      '';
    }
  ];

  # Installation resolves the zone once and saves it in settings.nix.
  # Keep runtime wall-clock and daylight-saving rules deterministic; no geolocation.
  time.timeZone = settings.timeZone;

  # Clock synchronization does not require geolocation: NTP synchronizes UTC,
  # then the configured IANA zone determines what Plasma displays locally.
  services.timesyncd.enable = true;

  i18n.defaultLocale = settings.defaultLocale;
  console.keyMap = settings.consoleKeyMap;

  networking = {
    networkmanager = {
      enable = true;

      # Scans already use a fresh random address. Associated Wi-Fi networks
      # receive a stable address derived from the SSID, while wired profiles
      # receive a separate stable randomized address. This avoids exposing the
      # hardware address across networks without breaking DHCP leases on every
      # reconnect.
      wifi = {
        powersave = settings.network.wifiPowerSave;
        scanRandMacAddress = true;
        macAddress = "stable-ssid";
      };
      ethernet.macAddress = "stable";

      # Do not advertise the persistent hostname to DHCP servers.
      connectionConfig = {
        "ipv4.dhcp-send-hostname" = false;
        "ipv6.dhcp-send-hostname" = false;

        # Captive portals require their DHCP resolver before authentication.
        # Otherwise keep LAN-provided DNS out of the normal resolver policy;
        # manual DNS on imported VPN profiles remains usable for routed domains.
        "ipv4.ignore-auto-dns" = !settings.network.captivePortalMode;
        "ipv6.ignore-auto-dns" = !settings.network.captivePortalMode;
      };
    };

    # NixOS maps this value to preferred IPv6 temporary addresses (RFC 8981)
    # and NetworkManager inherits it for newly created profiles.
    tempAddresses = "default";

    # This is normally enabled by NixOS, but declaring it makes the laptop's
    # closed-by-default inbound policy explicit and reviewable.
    firewall.enable = true;
  };

  # A short-lived travel mode for captive Wi-Fi. It changes only the active
  # connection profile and restores its previous DNS settings on stop/timeout.
  systemd.services.captive-portal-mode = {
    description = "Temporarily enable captive-portal DNS on the active Wi-Fi";
    wantedBy = [ ];
    wants = [ "captive-portal-mode.timer" ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      ExecStart = "${captivePortalScript}/bin/captive-portal-mode activate";
      ExecStop = "${captivePortalScript}/bin/captive-portal-mode deactivate";
    };
  };

  systemd.services.captive-portal-mode-stop = {
    description = "End temporary captive-portal mode";
    serviceConfig = {
      Type = "oneshot";
      ExecStart = "${pkgs.systemd}/bin/systemctl stop captive-portal-mode.service";
    };
  };

  systemd.timers.captive-portal-mode = {
    description = "Automatically end temporary captive-portal mode";
    partOf = [ "captive-portal-mode.service" ];
    timerConfig = {
      OnActiveSec = settings.network.captivePortalTimeout;
      AccuracySec = "1s";
      Unit = "captive-portal-mode-stop.service";
    };
  };

  # Permit only the proprietary packages deliberately retained by this build.
  # Keep the binary and wrapper names because Nixpkgs checks each derivation.
  nixpkgs.config.allowUnfreePackages = [
    "sublimetext4-secure"
    "sublimetext4"
    "sublimetext4-bin"
    "sublime-merge"
    "sublime-merge-bin"
    "dropbox"
    "firefox-bin"
    "firefox-bin-unwrapped"
    "steam"
    "steam-unwrapped"
    "onetab"
    "enhancer-for-youtube"
  ];

  nix.settings = {
    # Only root and the login account selected in settings.nix may submit
    # builds to the daemon. Do not make the whole wheel group trusted:
    # trusted Nix users can supply options with root-equivalent impact.
    allowed-users = [
      "root"
      user.name
    ];
    # NixOS already contributes root to this list. Force the complete value so
    # it remains one explicit entry instead of merging duplicate/default users.
    trusted-users = lib.mkForce [ "root" ];

    experimental-features = [
      "nix-command"
      "flakes"
    ];
  };

  # Run store deduplication as a low-priority, AC-only scheduled job instead
  # of adding latency to every Nix store write.
  nix.optimise = {
    automatic = true;
    dates = "weekly";
  };

  # Recent kernel while retaining the stable 26.05 userspace baseline.
  boot.kernelPackages = pkgs.linuxPackages_latest;

  boot.loader.efi.canTouchEfiVariables = true;

  # Needed for systemd-based initrd, LUKS2 token integration and clean
  # future TPM2 enrollment.
  boot.initrd.systemd.enable = true;

  services.fwupd.enable = true;
  services.hardware.bolt.enable = settings.features.thunderbolt;

  services.fstrim = {
    enable = true;
    interval = "weekly";
  };

  users.users.${user.name} = {
    isNormalUser = true;
    description = user.description;
    shell = pkgs.zsh;

    # A user with neither option is deliberately created locked. The install
    # guide sets its password inside /mnt after nixos-install, keeping password
    # material out of the flake and Nix store.
    hashedPassword = lib.mkIf hasHashedPassword user.hashedPassword;
    initialPassword = lib.mkIf hasInitialPassword user.initialPassword;

    openssh.authorizedKeys.keys = user.sshAuthorizedKeys;

    extraGroups = [
      "wheel"
      "networkmanager"
      "video"
      "render"
      "audio"
    ];
  };

  # Shell must be enabled at system level if used as login shell.
  programs.zsh.enable = true;

  # sshd is only useful together with an authorized key. Without one it
  # would sit listening on port 22 of every network the laptop joins, so
  # it follows settings.user.sshAuthorizedKeys.
  services.openssh = {
    enable = user.sshAuthorizedKeys != [ ];
    settings = {
      PasswordAuthentication = false;
      PermitRootLogin = "no";
    };
  };

  environment.systemPackages = with pkgs; [
    # Keep only rescue / system administration tools here.
    vim
    git
    curl
    wget

    # NetworkManager has native WireGuard support; these provide wg and
    # wg-quick for inspection, troubleshooting and non-GUI use.
    wireguard-tools

    alsa-utils
    pciutils
    usbutils
    lm_sensors
    powertop
    nvme-cli
    smartmontools
    vulkan-tools
    mesa-demos
    libva-utils
    clinfo
  ];

  fonts.packages = with pkgs; [
    nerd-fonts.jetbrains-mono
    noto-fonts
    noto-fonts-cjk-sans
    noto-fonts-color-emoji
  ];

  nix.gc = {
    automatic = true;
    dates = "weekly";
    options = "--delete-older-than 30d";
  };

  nixpkgs.overlays = [
    (final: prev: {
      pythonPackagesExtensions =
        (prev.pythonPackagesExtensions or [])
        ++ [
          (python-final: python-prev: {
            fpdf2 = python-prev.fpdf2.overridePythonAttrs (old: {
              disabledTests =
                (old.disabledTests or [])
                ++ [ "test_image_with_explicit_dimensions" ];
            });
          })
        ];
    })
  ];
}
