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
in
{
  assertions = [
    {
      assertion = !(hasHashedPassword && hasInitialPassword);
      message = ''
        settings.nix: set at most one of user.hashedPassword or
        user.initialPassword. Prefer leaving both null and setting the password
        with nixos-enter after installation, as documented in docs/INSTALL.md.
      '';
    }
    {
      assertion = user.initialPassword != "changeme";
      message = ''
        settings.nix: replace the unsafe "changeme" initial password.
      '';
    }
  ];

  # Keep wall-clock display and daylight-saving rules deterministic without
  # sharing location data. Change the IANA zone in settings.nix after travel.
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

        # Ignore DNS learned automatically from each LAN. Manual DNS attached
        # to an imported VPN profile is still usable for its routed domains.
        "ipv4.ignore-auto-dns" = true;
        "ipv6.ignore-auto-dns" = true;
      };
    };

    # NixOS maps this value to preferred IPv6 temporary addresses (RFC 8981)
    # and NetworkManager inherits it for newly created profiles.
    tempAddresses = "default";

    # This is normally enabled by NixOS, but declaring it makes the laptop's
    # closed-by-default inbound policy explicit and reviewable.
    firewall.enable = true;
  };

  # Permit only the proprietary packages deliberately retained by this build.
  # Keep the binary and wrapper names because Nixpkgs checks each derivation.
  nixpkgs.config.allowUnfreePackages = [
    "sublimetext4-secure"
    "sublimetext4"
    "sublimetext4-bin"
    "sublime-merge"
    "sublime-merge-bin"
    "brave"
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
}
