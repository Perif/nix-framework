{ pkgs, ... }:

{
  # Use Tor Browser only for anonymous web browsing. It carries Tor Project's
  # anti-fingerprinting patches and its own Tor client; ordinary Firefox is not
  # proxied through Tor and no background Tor SOCKS service is exposed.
  home.packages = [ pkgs.tor-browser ];
}
