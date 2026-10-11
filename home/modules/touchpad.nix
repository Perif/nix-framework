{
  config,
  lib,
  pkgs,
  settings,
  ...
}:

let
  cfg = settings.touchpad;
  isNumber = value: builtins.isInt value || builtins.isFloat value;
  preferences = {
    DisableWhileTyping = cfg.disableWhileTyping;
    TapToClick = cfg.tapToClick;
    TapAndDrag = cfg.tapAndDrag;
    TapDragLock = cfg.tapDragLock;
    LmrTapButtonMap = false; # One/two/three-finger taps: left/right/middle.
    ClickMethod = if cfg.clickMethod == "clickfinger" then 2 else 1;
    ScrollMethod = 1; # libinput two-finger scrolling.
    NaturalScroll = cfg.naturalScrolling;
    PointerAcceleration = cfg.pointerAcceleration;
    ScrollFactor = cfg.scrollFactor;
  };
  valueString = value: if builtins.isBool value then lib.boolToString value else toString value;
in
lib.mkIf cfg.enable {
  assertions = [
    {
      assertion = builtins.elem cfg.clickMethod [
        "clickfinger"
        "button-areas"
      ];
      message = "touchpad.clickMethod must be clickfinger or button-areas.";
    }
    {
      assertion =
        isNumber cfg.pointerAcceleration && cfg.pointerAcceleration >= -1 && cfg.pointerAcceleration <= 1;
      message = "touchpad.pointerAcceleration must be a number between -1 and 1.";
    }
    {
      assertion = isNumber cfg.scrollFactor && cfg.scrollFactor > 0;
      message = "touchpad.scrollFactor must be a positive number.";
    }
    {
      assertion = builtins.all builtins.isBool [
        cfg.disableWhileTyping
        cfg.tapToClick
        cfg.tapAndDrag
        cfg.tapDragLock
        cfg.naturalScrolling
      ];
      message = "Touchpad typing, tapping, dragging and natural-scrolling switches must be booleans.";
    }
  ];

  # KWin 6.6 reads touchpad-specific defaults from this nested group. Per-device
  # preferences override them. Keep kcminputrc writable and preserve unrelated
  # input settings; NixOS services.libinput would only configure Xorg here.
  # Log out/in after activation so KWin reloads the defaults.
  home.activation.touchpadDefaults = lib.hm.dag.entryAfter [ "writeBoundary" ] (
    lib.concatStringsSep "\n" (
      lib.mapAttrsToList (key: value: ''
        run ${pkgs.kdePackages.kconfig}/bin/kwriteconfig6 \
          --file ${lib.escapeShellArg "${config.xdg.configHome}/kcminputrc"} \
          --group Libinput --group Defaults --group Touchpad \
          --key ${lib.escapeShellArg key} -- ${lib.escapeShellArg (valueString value)}
      '') preferences
    )
  );
}
