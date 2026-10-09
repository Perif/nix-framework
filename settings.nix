# Machine and user parameters.
#
# This is the only file that needs to change for installation-specific values.
# flake.nix passes it to every NixOS and Home Manager module as the `settings`
# argument.
{
  # networking.hostName and the flake output name:
  #   nixos-rebuild switch --flake .#<hostname>
  hostname = "framework-pro";

  # Resolve once during installation: nix run .#detect-timezone
  # null requires detection (or an explicit IANA zone) before system evaluation.
  # The saved zone stays fixed after installation; GeoClue remains disabled.
  timeZone = null;
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
    wine = true;
    keepassxc = true;
    # Upstream QBZ source and distribution were withdrawn in September 2026.
    # Enable only after supplying your own package recipe below.
    qbz = false;

    # Leave false for the initial installation. After the first boot, create
    # and verify local Secure Boot keys by following docs/INSTALL.md, then set
    # this to true before enabling Secure Boot in firmware.
    secureBoot = false;

    # Optional Thunderbolt/USB4 authorization daemon for docks that need it.
    # This does not automatically authorize unknown devices.
    thunderbolt = false;

    # Software groups are installed by default to preserve the current
    # workstation. Disable an application group here to reduce the closure.
    # Development core includes common CLI tools and rootless Podman; language
    # toolchains can be selected independently below.
    devCore = true;
    languageTools = {
      c = true;
      python = true;
      go = true;
      rust = true;
      nodejs = true;
      nix = true;
    };

    localAI = true;
    extraBrowsers = true; # Brave and ungoogled Chromium; Firefox stays installed.
    extraEditors = true; # VSCodium and Sublime Text/Merge; Vim stays installed.

    office = {
      libreOffice = true;
      thunderbird = true;
      kdeConnect = true;
      syncthing = true;
    };
  };

  qbz = {
    # Optional path to a user-supplied Nix package recipe, evaluated using
    # pkgs.callPackage. Enabling features.qbz requires an existing Nix path,
    # for example ./local/qbz.nix. Add it to Git before flake evaluation.
    packageFile = null;
  };

  # Plasma applies these on login and when the power source changes. PPD owns
  # Intel EPP/platform policy; do not also run TLP or a governor-switching script.
  power = {
    acProfile = "performance";
    batteryProfile = "balanced";
    lowBatteryProfile = "power-saver";
    maintenanceOnAC = true; # Defer GC/scrub on battery, retry pending work on AC.
    chargeLimit = 80; # 1..100, or null to leave firmware/Plasma in control.
  };

  # null retains NixOS defaults until measurements on the actual laptop.
  # maxJobs: positive integer or "auto"; cores: nonnegative integer (0 = all).
  # See docs/PERFORMANCE.md before choosing limits for builds alongside AI.
  builds = {
    maxJobs = null;
    cores = null;
  };

  storage.homeSnapshots = false; # Optional short-retention /home snapshots.

  network = {
    # null: NetworkManager default; false: disable power saving as a Wi-Fi
    # reliability workaround; true: enable power saving. See docs/NETWORKING.md.
    wifiPowerSave = null;
  };

  ai = {
    webui = {
      enable = true; # Installed, localhost-only, started on demand.
      port = 3000; # Keep 8080 free for llama.cpp.
      # Signup stays disabled. Run `sudo webui-bootstrap` once to create the
      # administrator interactively without placing credentials in this file.
    };
    # A bounded starting point for 32 GiB shared CPU/GPU memory, not a RAM cap.
    contextLength = 8192;
    maxOutputTokens = 2048;
    maxLoadedModels = 1;
    parallelRequests = 1;
    keepAlive = "5m";
    # f16 preserves quality. q8_0 halves KV storage where Flash Attention works;
    # benchmark model quality/latency before changing it. FA stays auto-detected.
    kvCacheType = "f16";
    ollaya = {
      enable = true;
    };
  };

  # Profile selection installs a stable alias; apply it in Plasma afterward.
  # "native" requires selecting the default/no-ICC mode in Plasma explicitly.
  display = {
    profile = "notebookcheck"; # "notebookcheck", "native", or "custom"
    iccProfile = null; # For "custom", e.g. ./assets/color/my-panel.icc
    # Additional measured profiles to install for comparison in Plasma.
    # Example: studio = ./assets/color/my-panel-120nits.icc;
    extraIccProfiles = { };
  };

  # Optional declarative EasyEffects autoload binding. Copy both exact fields
  # from a speaker-only rule made in EasyEffects (docs/AUDIO.md). Until then,
  # the preset is installed but must be selected/associated in the GUI.
  # Do not use a headphone route or a generic sound-card profile here.
  audio = {
    # Available: "FW13SpeakersV2-Loudness", "FW13Pro-EQ-Limiter",
    # "FW13Pro-bit0fun", "Flat", or "Custom" (requires customPreset).
    # All bundled presets remain available in the GUI. This chooses the
    # declarative speaker autoload rule when device and route are both set.
    speakerPreset = "FW13SpeakersV2-Loudness";
    customPreset = null; # EasyEffects output JSON, e.g. ./assets/audio/mine.json
    speakerDevice = null;
    speakerRoute = null;
  };

  git = {
    userName = "PY";
    userEmail = "py@example.invalid";
  };
}
