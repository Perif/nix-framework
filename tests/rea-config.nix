{ pkgs }:
let
  inherit (pkgs) lib;
  base = import ../settings.nix;
  # Keep the test matrix stable when an installation selects other features.
  settings = base // {
    features = base.features // {
      rea = true;
      localAI = true;
      extraEditors = true;
    };
    rea = base.rea // {
      ollayaMcp = false;
    };
    ai = base.ai // {
      ollaya.enable = true;
    };
  };
  homeDirectory = "/home/test-user";
  generate =
    selection:
    import ../home/modules/continue-config.nix {
      inherit pkgs lib homeDirectory;
      settings = selection;
    };
  default = generate settings;
  optional = generate (
    settings
    // {
      rea = settings.rea // {
        ollayaMcp = true;
      };
    }
  );
  disabled = generate (
    settings
    // {
      features = settings.features // {
        rea = false;
      };
    }
  );
  model = builtins.elemAt default.models 2;
  decisionServer = builtins.elemAt optional.mcpServers 1;
  environment = import ../home/modules/ollaya-environment.nix { inherit homeDirectory; };
  accepted =
    selection:
    builtins.all (check: check.assertion)
      (import ../home/modules/rea.nix {
        inherit pkgs;
        settings = selection;
      }).assertions;
in
assert builtins.length default.mcpServers == 1;
assert (builtins.head default.mcpServers).args == [ "mcp" ];
assert (builtins.head default.mcpServers).connectionTimeout == 300000;
assert lib.hasPrefix "/nix/store/" (builtins.head default.mcpServers).command;
assert model.provider == "ollama" && model.apiBase == "http://127.0.0.1:11434";
assert model.model == settings.rea.ollamaModel && model.capabilities == [ "tool_use" ];
assert model.defaultCompletionOptions.contextLength == settings.ai.contextLength;
assert model.defaultCompletionOptions.maxTokens == settings.ai.maxOutputTokens;
assert builtins.length optional.mcpServers == 2;
assert decisionServer.args == [ "mcp" ] && decisionServer.env == environment;
assert !(disabled ? mcpServers) && builtins.length disabled.models == 2;
assert accepted settings;
assert accepted (
  settings
  // {
    rea = settings.rea // {
      ollayaMcp = true;
    };
  }
);
assert
  !(accepted (
    settings
    // {
      rea = settings.rea // {
        ollayaMcp = true;
      };
      ai = settings.ai // {
        ollaya.enable = false;
      };
    }
  ));
assert
  !(accepted (
    settings
    // {
      rea = settings.rea // {
        ollayaMcp = true;
      };
      features = settings.features // {
        localAI = false;
      };
    }
  ));
assert
  !(accepted (
    settings
    // {
      rea = settings.rea // {
        ollayaMcp = true;
      };
      features = settings.features // {
        extraEditors = false;
      };
    }
  ));
true
