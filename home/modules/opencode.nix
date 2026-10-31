
{ pkgs, ... }:

{
  programs.opencode = {
    enable = true;
    package = pkgs.opencode;

    settings = {
      # Keep the interactive default small enough to leave ample headroom for
      # Plasma and Intel's shared GPU memory.  The 30B coding model below is
      # available for occasional harder tasks, but is not the default.
      model = "ollama/qwen2.5-coder:7b";
      autoshare = false;

      provider.ollama = {
        npm = "@ai-sdk/openai-compatible";
        name = "Ollama (local)";

        options = {
          baseURL = "http://127.0.0.1:11434/v1";
        };

        models = {
          "qwen3-coder:30b" = {
            name = "Qwen3-Coder 30B (quality, slower)";
            tool_call = true;
            reasoning = true;
          };

          "qwen2.5-coder:7b" = {
            name = "Qwen2.5-Coder 7B (default)";
            tool_call = true;
          };

          "qwen3:8b" = {
            name = "Qwen3 8B (fast fallback)";
            tool_call = true;
            reasoning = true;
          };
        };
      };

      permission = {
        edit = "allow";
        bash = "ask";
        external_directory = "ask";
        webfetch = "ask";
        websearch = "ask";
      };
    };

    context = ''
      # Development instructions

      - Inspect the existing repository structure before making changes.
      - Prefer minimal, declarative changes over imperative modifications.
      - Preserve existing coding conventions and module organization.
      - Never run sudo, nixos-rebuild switch, or destructive disk commands.
      - For NixOS changes, validate with nixos-rebuild build.
      - Explain failures rather than introducing unrelated changes.
    '';
  };

  # Enable OpenCode's hosted Exa-backed search tool for the local Ollama
  # provider. Searches still require an explicit confirmation above.
  home.sessionVariables.OPENCODE_ENABLE_EXA = "1";
}
