{ ... }:

{
  # Only wheel members may execute sudo, and authentication remains required.
  security.sudo = {
    execWheelOnly = true;
    wheelNeedsPassword = true;
  };

  # Low-risk kernel and network hardening that is compatible with hibernation,
  # rootless Podman and ordinary VPN clients. More invasive controls such as
  # disabling user namespaces or kernel module loading are intentionally not
  # used because this workstation depends on those facilities.
  boot.kernel.sysctl = {
    "kernel.kptr_restrict" = 2;
    "kernel.dmesg_restrict" = 1;
    "kernel.yama.ptrace_scope" = 1;
    "kernel.unprivileged_bpf_disabled" = 1;
    "net.core.bpf_jit_harden" = 2;

    "net.ipv4.conf.all.accept_redirects" = 0;
    "net.ipv4.conf.default.accept_redirects" = 0;
    "net.ipv4.conf.all.send_redirects" = 0;
    "net.ipv4.conf.default.send_redirects" = 0;
    "net.ipv4.conf.all.accept_source_route" = 0;
    "net.ipv4.conf.default.accept_source_route" = 0;
    "net.ipv4.icmp_echo_ignore_broadcasts" = 1;

    # This workstation is never an IPv6 router. Reject ICMPv6 redirects and
    # every IPv6 source-routing header, including Mobile IPv6 type 2, while
    # retaining normal router advertisements and temporary addressing.
    "net.ipv6.conf.all.accept_redirects" = 0;
    "net.ipv6.conf.default.accept_redirects" = 0;
    "net.ipv6.conf.all.accept_source_route" = -1;
    "net.ipv6.conf.default.accept_source_route" = -1;
  };

  # Core images may contain passwords, keys or decrypted application data.
  # Keep systemd-coredump as the kernel handler but discard the payload and do
  # not process a backtrace from it.
  systemd.coredump.settings.Coredump = {
    Storage = "none";
    ProcessSizeMax = 0;
  };

  # Logs remain useful for security and fault diagnosis, but bound their
  # retention and disk footprint. /var/log is inside the encrypted disk.
  services.journald = {
    forwardToSyslog = false;
    extraConfig = ''
      Compress=yes
      Seal=yes
      SystemMaxUse=512M
      MaxRetentionSec=14day
    '';
  };

  # Framework's nixos-hardware module enables this as well; explicit here
  # because fingerprint authentication is part of this machine's policy.
  services.fprintd.enable = true;

  # Keep fingerprints available for login, Plasma unlock, and local sudo.
  # Plasma installs its dedicated kde-fingerprint PAM service when fprintd is
  # enabled; sudo retains its password fallback when the reader is unavailable.
  security.pam.services.login.fprintAuth = true;
  security.pam.services.sddm.fprintAuth = true;
  security.pam.services.sudo.fprintAuth = true;

  # TPM2 LUKS auto-unlock is deliberately not enabled on first install.
  # See docs/24-fingerprint-tpm.md after validating cold boot + hibernate.
}
