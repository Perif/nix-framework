{
  configuration,
  settings,
  lib,
}:
let
  minimal = settings // {
    timeZone = "UTC";
    diskDevice = "/dev/disk/by-id/evaluation-only";
    display = settings.display // {
      disableHdr = true;
    };
    rea = settings.rea // {
      ollayaMcp = false;
    };
    features = settings.features // {
      devCore = false;
      languageTools = lib.mapAttrs (_: _: false) settings.features.languageTools;
      localAI = false;
      rea = false;
      extraBrowsers = false;
      extraEditors = false;
      office = lib.mapAttrs (_: _: false) settings.features.office;
    };
  };
  evaluate =
    selection:
    (configuration.extendModules {
      specialArgs.settings = selection;
      modules = [ { home-manager.extraSpecialArgs = lib.mkForce { settings = selection; }; } ];
    }).config;
  cfg = evaluate minimal;
  home = cfg.home-manager.users.${settings.user.name};
  pythonOnly = evaluate (
    minimal
    // {
      features = minimal.features // {
        extraEditors = true;
        languageTools = minimal.features.languageTools // {
          python = true;
        };
      };
      display = minimal.display // {
        disableHdr = false;
        refreshRate = minimal.display.refreshRate // {
          enable = true;
        };
      };
    }
  );
  pythonHome = pythonOnly.home-manager.users.${settings.user.name};
  guileOnly = evaluate (
    minimal
    // {
      touchpad = settings.touchpad // {
        enable = false;
      };
      display = settings.display // {
        disableHdr = false;
      };
      features = minimal.features // {
        languageTools = minimal.features.languageTools // {
          guile = true;
        };
      };
    }
  );
  guileHome = guileOnly.home-manager.users.${settings.user.name};
  reaOnly = evaluate (
    minimal
    // {
      features = minimal.features // {
        rea = true;
      };
    }
  );
  reaHome = reaOnly.home-manager.users.${settings.user.name};
  hasRea =
    homeConfig:
    builtins.any (package: (package.meta.mainProgram or "") == "rea") homeConfig.home.packages;
  hasGhidra =
    homeConfig:
    builtins.any (
      package: (package.pname or "") == "ghidra" && package.version == "12.1.4"
    ) homeConfig.home.packages;
  hasGuile =
    homeConfig: builtins.any (package: (package.pname or "") == "guile") homeConfig.home.packages;
in
assert !cfg.services.ollama.enable;
assert !cfg.services.open-webui.enable;
assert !cfg.virtualisation.podman.enable;
assert !cfg.programs.chromium.enable;
assert !home.programs.vscodium.enable;
assert !home.programs.direnv.enable;
assert !home.programs.fzf.enable;
assert !home.programs.zoxide.enable;
assert !home.programs.delta.enable;
assert !cfg.programs.kdeconnect.enable;
assert !cfg.services.syncthing.enable;
assert pythonHome.programs.vscodium.enable;
assert !pythonHome.programs.direnv.enable;
assert !(pythonHome.home.file ? ".continue/config.yaml");
assert !hasGuile home && !hasGuile pythonHome && hasGuile guileHome;
assert !guileHome.programs.direnv.enable;
assert !(guileHome.home.activation ? touchpadDefaults);
assert home.systemd.user.services ? framework-display-sdr;
assert home.systemd.user.paths ? framework-display-sdr;
assert pythonHome.systemd.user.services ? framework-display-sdr;
assert pythonHome.systemd.user.paths ? framework-display-sdr;
assert !(guileHome.systemd.user.services ? framework-display-sdr);
assert !(guileHome.systemd.user.paths ? framework-display-sdr);
assert !hasRea home && !hasRea pythonHome && hasRea reaHome;
assert !hasGhidra home && hasGhidra reaHome;
assert !reaOnly.services.ollama.enable;
assert !reaHome.programs.vscodium.enable;
assert !(reaHome.home.file ? ".continue/config.yaml");
# Evaluate complete generations too: conditional package selection must not
# hide missing option references or assertions in either smaller profile.
builtins.deepSeq [
  cfg.system.build.toplevel.drvPath
  pythonOnly.system.build.toplevel.drvPath
  guileOnly.system.build.toplevel.drvPath
  reaOnly.system.build.toplevel.drvPath
] true
