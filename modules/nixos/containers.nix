{ settings, ... }:

{
  # Rootless Podman needs system-level pieces that a Home Manager package
  # cannot provide: the setuid newuidmap/newgidmap wrappers, subordinate
  # UID/GID ranges for the user, and /etc/containers policy. The
  # podman-compose CLI stays in Home Manager (home/modules/dev-tools.nix).
  virtualisation.podman = {
    enable = true;

    # Container-to-container name resolution for podman-compose networks.
    defaultNetwork.settings.dns_enabled = true;
  };

  # Keep the subordinate UID/GID allocation explicit for this rootless
  # container user, even though current NixOS normally defaults it on.
  users.users.${settings.user.name}.autoSubUidGidRange = true;
}
