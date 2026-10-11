{
  pkgs,
  lib,
  settings,
  homeDirectory,
}:
let
  modelDefaults = {
    roles = [
      "chat"
      "edit"
      "apply"
    ];
    defaultCompletionOptions = {
      contextLength = settings.ai.contextLength;
      maxTokens = settings.ai.maxOutputTokens;
    };
    requestOptions.noProxy = [
      "127.0.0.1"
      "localhost"
    ];
  };
  rea = pkgs.callPackage ../../pkgs/rea-with-ghidra.nix { };
  ollaya = pkgs.callPackage ../../pkgs/ollaya.nix { };
in
{
  name = "Local-only development";
  version = "1.0.0";
  schema = "v1";
  models = [
    (
      modelDefaults
      // {
        name = "Ollama local models";
        provider = "ollama";
        model = "AUTODETECT";
        apiBase = "http://127.0.0.1:11434";
      }
    )
    (
      modelDefaults
      // {
        name = "llama.cpp local server";
        provider = "llama.cpp";
        model = "local";
        apiBase = "http://127.0.0.1:8080";
      }
    )
  ]
  ++ lib.optional settings.features.rea (
    modelDefaults
    // {
      name = "REA via Ollama";
      provider = "ollama";
      model = settings.rea.ollamaModel;
      apiBase = "http://127.0.0.1:11434";
      capabilities = [ "tool_use" ];
    }
  );
}
// lib.optionalAttrs settings.features.rea {
  mcpServers = [
    {
      name = "REA";
      command = "${rea}/bin/rea";
      args = [ "mcp" ];
    }
  ]
  ++ lib.optional settings.rea.ollayaMcp {
    name = "Ollaya decisions";
    command = "${ollaya}/bin/ollaya";
    args = [ "mcp" ];
    env = import ./ollaya-environment.nix { inherit homeDirectory; };
  };
}
