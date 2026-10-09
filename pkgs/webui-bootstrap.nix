{
  pkgs,
  port ? null,
}:

pkgs.writeShellApplication {
  name = "webui-bootstrap";
  runtimeInputs = with pkgs; [ systemd ];
  text = ''
    exec ${pkgs.python3}/bin/python3 ${../scripts/webui-bootstrap.py} ${
      pkgs.lib.optionalString (port != null) "--port ${toString port}"
    } "$@"
  '';
}
