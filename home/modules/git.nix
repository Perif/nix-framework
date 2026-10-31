{
  lib,
  pkgs,
  ...
}:

let
  # CI imports this exact implementation, not a separate imitation of the hook.
  inherit (import ./git-hooks { inherit lib pkgs; }) piiScanner securityPreCommit;
in

{
  home.packages = [
    pkgs.gitleaks
    piiScanner
  ];

  programs.git = {
    enable = true;

    # Installs git-lfs and writes the filter.lfs configuration, which a bare
    # git-lfs package in home.packages does not do.
    lfs.enable = true;

    # Home Manager creates an immutable core.hooksPath containing this hook.
    # The hook also calls an existing .git/hooks/pre-commit afterward.
    hooks.pre-commit = "${securityPreCommit}/bin/git-security-pre-commit";

    settings = {
      # Personal identity belongs in this untracked local include, not in the
      # declarative repository. Create it once with `git config --file
      # ~/.config/git/local user.name "..."` and the equivalent user.email.
      include.path = "~/.config/git/local";

      init.defaultBranch = "main";
      commit.verbose = true;
      core.whitespace = "trailing-space,space-before-tab";
      diff = {
        algorithm = "histogram";
        colorMoved = "default";
      };
      fetch.prune = true;
      merge.conflictStyle = "zdiff3";
      pull.rebase = false;
      push.default = "simple";
      push.autoSetupRemote = true;

      # These default to enabled and can be disabled only in a specific
      # repository after documenting why. Client-side hooks remain bypassable
      # with Git's standard --no-verify option.
      hooks = {
        gitleaks = true;
        piiCheck = true;
      };
    };
  };
}
