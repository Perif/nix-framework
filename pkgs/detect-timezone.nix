{ pkgs }:
pkgs.writeShellApplication {
  name = "detect-timezone";
  runtimeInputs = [ pkgs.python3 ];
  text = ''
    export PYTHONTZPATH="${pkgs.tzdata}/share/zoneinfo"
    export SSL_CERT_FILE="${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt"
    exec python3 ${../scripts/detect-timezone.py} "$@"
  '';
}
