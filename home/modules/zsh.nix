{ pkgs, settings, ... }:

{
  # Packages required by aliases in this module.
  home.packages = [ pkgs.yt-dlp ];

  programs.zsh = {
    enable = true;
    enableCompletion = true;

    autosuggestion.enable = true;
    syntaxHighlighting.enable = true;

    history = {
      path = "$HOME/.histfile";
      size = 10000;
      save = 10000;
      ignoreDups = true;
      ignoreAllDups = true;
      saveNoDups = true;
      expireDuplicatesFirst = true;

      # Prefix a sensitive one-off command with a space to exclude it from the
      # history file. Do not stream each command to other open shells.
      ignoreSpace = true;
      share = false;
    };

    shellAliases = {
      ls = "ls --color=auto";
      ll = "ls -alF";
      la = "ls -A";
      lr = "ls -rt";

      reload = "source ~/.zshrc";

      cp = "cp -i";
      mv = "mv -i";

      gs = "git status";
      hg = "history | grep ";

      jobs = "jobs -p";

      ph = "ps auwwx | head";
      pg = "ps auwwx | grep -i -e ^USER -e ";

      publicip = "curl -w '\\n' -s https://ifconfig.me";

      yt-best = ''yt-dlp --format "bestvideo+bestaudio/best" --merge-output-format mp4 --write-subs --write-auto-subs --sub-lang en --embed-subs --convert-subs srt --embed-thumbnail --add-metadata'';

      # Common NixOS workflow. The explicit names make the activation behavior
      # visible before a command is run: dry-build previews builds, test is
      # temporary, boot activates after reboot, and switch activates now.
      rebuild = "sudo nixos-rebuild switch --flake /etc/nixos#${settings.hostKey}";
      ncheck = "nix flake check --no-build --all-systems /etc/nixos";
      nix-check = "nix flake check --no-build --all-systems /etc/nixos";
      nix-show = "nix flake show /etc/nixos";
      nix-metadata = "nix flake metadata /etc/nixos";
      nix-update = "sudo nix flake update --flake /etc/nixos";
      nix-dry = "sudo nixos-rebuild dry-build --flake /etc/nixos#${settings.hostKey}";
      nix-test = "sudo nixos-rebuild test --flake /etc/nixos#${settings.hostKey}";
      nix-boot = "sudo nixos-rebuild boot --flake /etc/nixos#${settings.hostKey}";
      nix-switch = "sudo nixos-rebuild switch --flake /etc/nixos#${settings.hostKey}";
      nix-generations = "sudo nix-env --profile /nix/var/nix/profiles/system --list-generations";
      nix-search = "nix search nixpkgs";
      nix-why = "nix why-depends /run/current-system";

    };

    # Keep the user's prompt and shell behavior explicit. Starship is not
    # enabled because it would replace PROMPT.
    initContent = ''
      setopt noclobber
      setopt nohup
      setopt print_exit_value

      TMOUT=0

      USE_POWERLINE="true"
      HAS_WIDECHARS="false"

      # Inherit LANG and category-specific locale settings from the system.
      # In particular, do not override settings.defaultLocale with LC_ALL.

      # Keep CLI editing in the shell rather than imposing it on every
      # application running in Ghostty.
      bindkey -e
      bindkey '^A' beginning-of-line
      bindkey '^W' backward-kill-word
      bindkey '^[[1;5D' backward-word
      bindkey '^[[1;5C' forward-word

    '';
  };

  programs.starship = {
    enable = true;
    enableZshIntegration = true;
  };
}
