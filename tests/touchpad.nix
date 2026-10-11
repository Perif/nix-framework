{ pkgs }:
let
  # Exercise the production activation with real KConfig, using a disposable
  # directory and Home Manager's run interface without activating a user home.
  module = import ../home/modules/touchpad.nix {
    inherit pkgs;
    settings.touchpad = (import ../settings.nix).touchpad // {
      enable = true;
      tapToClick = true;
      tapAndDrag = false;
      pointerAcceleration = -0.25;
    };
    config.xdg.configHome = "${builtins.placeholder "out"}/config";
    lib = pkgs.lib // {
      hm.dag.entryAfter = _: script: script;
    };
  };
  activation = module.content.home.activation.touchpadDefaults;
in
assert module.condition;
assert builtins.all (check: check.assertion) module.content.assertions;
pkgs.runCommand "touchpad-configuration-tests"
  {
    nativeBuildInputs = [ pkgs.kdePackages.kconfig ];
  }
  ''
    export QT_QPA_PLATFORM=offscreen
    mkdir -p "$out/config"
    cat > "$out/config/kcminputrc" <<'EOF'
    [Libinput][1234][5678][Existing Touchpad]
    TapToClick=false
    [Libinput][Defaults][Pointer]
    NaturalScroll=true
    [Mouse]
    cursorTheme=existing-theme
    EOF
    run() { "$@"; }
    ${activation}
    cp "$out/config/kcminputrc" once
    ${activation}
    cmp once "$out/config/kcminputrc"
    test "$(kreadconfig6 --file "$out/config/kcminputrc" --group Libinput --group 1234 --group 5678 --group 'Existing Touchpad' --key TapToClick)" = false
    test "$(kreadconfig6 --file "$out/config/kcminputrc" --group Libinput --group Defaults --group Pointer --key NaturalScroll)" = true
    test "$(kreadconfig6 --file "$out/config/kcminputrc" --group Mouse --key cursorTheme)" = existing-theme
    test "$(kreadconfig6 --file "$out/config/kcminputrc" --group Libinput --group Defaults --group Touchpad --key TapToClick)" = true
    test "$(kreadconfig6 --file "$out/config/kcminputrc" --group Libinput --group Defaults --group Touchpad --key TapAndDrag)" = false
    test "$(kreadconfig6 --file "$out/config/kcminputrc" --group Libinput --group Defaults --group Touchpad --key PointerAcceleration)" = -0.250000
    test ! -L "$out/config/kcminputrc"
  ''
