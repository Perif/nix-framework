{ pkgs }:

pkgs.writeShellApplication {
  name = "webui-bootstrap";
  runtimeInputs = with pkgs; [ systemd ];
  text = ''
    exec ${pkgs.python3}/bin/python3 ${../scripts/webui-bootstrap.py} "$@"
  '';
}
