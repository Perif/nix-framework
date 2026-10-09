{
  config,
  lib,
  pkgs,
  settings,
  ...
}:

let
  device = settings.audio.speakerDevice;
  route = settings.audio.speakerRoute;
  bound = device != null && route != null;
  preset = settings.audio.speakerPreset;
  bundledPresets = import ./easyeffects-presets.nix;
  custom = settings.audio.customPreset;
  customData = if custom == null then { } else builtins.fromJSON (builtins.readFile custom);
  customValid =
    builtins.isAttrs customData
    && builtins.attrNames customData == [ "output" ]
    && builtins.isAttrs customData.output
    && builtins.isList (customData.output.plugins_order or null);
  presets =
    bundledPresets // lib.optionalAttrs (custom != null && customValid) { Custom = customData; };
  jsonFormat = pkgs.formats.json { };
  # Match EasyEffects' own autoload filename escaping.
  escape = lib.replaceStrings [ "/" ] [ "_" ];
  configFile = "${config.xdg.configHome}/easyeffects/db/easyeffectsrc";
  kwrite = "${pkgs.kdePackages.kconfig}/bin/kwriteconfig6 --file ${lib.escapeShellArg configFile}";
in
{
  assertions = [
    {
      assertion = builtins.hasAttr preset presets;
      message = "audio.speakerPreset must name a bundled preset, or Custom with a valid customPreset output JSON.";
    }
    {
      assertion = custom == null || customValid;
      message = "audio.customPreset must contain only an output object with a plugins_order array.";
    }
    {
      assertion = (device == null) == (route == null);
      message = "Set both audio.speakerDevice and audio.speakerRoute, or leave both null.";
    }
    {
      assertion = !bound || (device != "" && route != "");
      message = "EasyEffects speaker autoload requires a non-empty device and speaker route.";
    }
    {
      assertion = lib.versionAtLeast pkgs.easyeffects.version "8.0.0";
      message = "The EasyEffects preset paths and fallback settings require EasyEffects 8 or later.";
    }
  ];

  services.easyeffects = {
    enable = true;
    # No global speaker startup preset: autoload matches device AND route.
    extraPresets = presets;
  };

  xdg.dataFile = lib.optionalAttrs bound {
    "easyeffects/autoload/output/${escape device}:${escape route}.json".source =
      jsonFormat.generate "framework-speaker-autoload.json"
        {
          inherit device;
          device-description = "Framework Laptop 13 Pro speakers";
          device-profile = route;
          preset-name = preset;
        };
  };

  # Set only our keys before starting the daemon; leave its other mutable GUI
  # settings alone. An unmatched device/route must clear the previous EQ.
  systemd.user.services.easyeffects.Service.ExecStartPre = [
    "${kwrite} --group Window --key outputAutoloadingUsesFallback --type bool true"
    "${kwrite} --group Window --key outputAutoloadingFallbackPreset Flat"
    "${kwrite} --group StreamOutputs --key useDefaultOutputDevice --type bool true"
    "${kwrite} --group EffectsPipelines --key processAllInputs --type bool false"
  ];
}
