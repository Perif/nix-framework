{ ... }:

{
  # Own the security-sensitive screen-lock settings for the configured Home
  # Manager user. Timeout is expressed in minutes; a zero grace period means
  # authentication is required as soon as the automatic lock engages.
  xdg.configFile."kscreenlockerrc".text = ''
    [Daemon]
    Autolock=true
    Lock=true
    LockGrace=0
    LockOnResume=true
    RequirePassword=true
    Timeout=5
  '';
}
