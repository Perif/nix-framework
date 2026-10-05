{
  lib,
  pkgs,
  settings,
  ...
}:

let
  cfg = settings.display;
  notebookcheck = ../../assets/color/framework-13-pro-MND508ZB1-1.icm;
  selected = if cfg.profile == "custom" then cfg.iccProfile else notebookcheck;
  validName = name: builtins.match "[A-Za-z0-9_-]+" name != null;
in
{
  assertions = [
    {
      assertion = builtins.elem cfg.profile [
        "notebookcheck"
        "native"
        "custom"
      ];
      message = "display.profile must be notebookcheck, native, or custom.";
    }
    {
      assertion = cfg.profile != "custom" || cfg.iccProfile != null;
      message = "display.profile = custom requires display.iccProfile to point to your measured ICC file.";
    }
    {
      assertion = builtins.all validName (builtins.attrNames cfg.extraIccProfiles);
      message = "display.extraIccProfiles names may contain only letters, digits, underscores, and hyphens.";
    }
  ];

  # KWin/Wayland applies the profile selected in Display Configuration.
  # Installing an ICC in colord alone does not apply it to a Wayland display.
  xdg.dataFile = {
    "color/icc/framework/notebookcheck-MND508ZB1-1.icm".source = notebookcheck;
  }
  // lib.optionalAttrs (cfg.profile != "native" && selected != null) {
    "color/icc/framework-13-pro.icm".source = selected;
  }
  // lib.mapAttrs' (
    name: source: lib.nameValuePair "color/icc/framework/custom-${name}.icc" { inherit source; }
  ) cfg.extraIccProfiles;

  # Read the internal panel EDID before applying a borrowed calibration.
  home.packages = [ pkgs.edid-decode ];
}
