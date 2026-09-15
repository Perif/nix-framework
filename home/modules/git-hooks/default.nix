{ lib, pkgs }:
let
  piiScanner = pkgs.writeShellApplication {
    name = "git-staged-pii-scan";
    runtimeInputs = [ pkgs.git ];
    text = ''
      exec ${lib.getExe pkgs.python3} ${./staged-pii-scan.py} "$@"
    '';
  };
  securityPreCommit = pkgs.writeShellApplication {
    name = "git-security-pre-commit";
    runtimeInputs = [
      pkgs.git
      pkgs.gitleaks
      piiScanner
    ];
    text = ''
      gitleaks_setting="$(git config --bool --get hooks.gitleaks 2>/dev/null || true)"
      if [[ "$gitleaks_setting" != "false" ]]; then
        gitleaks git --pre-commit --redact --staged --verbose
      else
        echo "Global Gitleaks scan disabled by this repository's Git config."
      fi
      pii_setting="$(git config --bool --get hooks.piiCheck 2>/dev/null || true)"
      if [[ "$pii_setting" != "false" ]]; then
        git-staged-pii-scan
      else
        echo "Global staged-PII scan disabled by this repository's Git config."
      fi
      local_hook="$(git rev-parse --path-format=absolute --git-common-dir)/hooks/pre-commit"
      if [[ -x "$local_hook" ]]; then
        "$local_hook" "$@"
      fi
    '';
  };
in
{
  inherit piiScanner securityPreCommit;
}
