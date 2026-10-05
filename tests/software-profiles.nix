{
  configuration,
  settings,
  lib,
}:
let
  minimal = settings // {
    timeZone = "UTC";
    diskDevice = "/dev/disk/by-id/evaluation-only";
    features = settings.features // {
      devCore = false;
      languageTools = lib.mapAttrs (_: _: false) settings.features.languageTools;
      localAI = false;
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
    }
  );
  pythonHome = pythonOnly.home-manager.users.${settings.user.name};
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
# Evaluate complete generations too: conditional package selection must not
# hide missing option references or assertions in either smaller profile.
builtins.deepSeq [ cfg.system.build.toplevel.drvPath pythonOnly.system.build.toplevel.drvPath ] true
