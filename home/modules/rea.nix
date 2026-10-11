{ pkgs, settings, ... }:
let
  rea = pkgs.callPackage ../../pkgs/rea-with-ghidra.nix { };
in
{
  home.packages = [
    rea
    rea.ghidra
  ];

  assertions = [
    {
      assertion =
        !settings.rea.ollayaMcp
        || (settings.features.localAI && settings.features.extraEditors && settings.ai.ollaya.enable);
      message = "rea.ollayaMcp requires features.localAI, features.extraEditors and ai.ollaya.enable.";
    }
    {
      assertion = builtins.isString settings.rea.ollamaModel && settings.rea.ollamaModel != "";
      message = "rea.ollamaModel must name a tool-capable Ollama model (for example qwen3:8b).";
    }
  ];
}
