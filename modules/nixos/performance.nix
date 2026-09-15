{ ... }:

{
  # Use the firmware-provided Intel DPTF tables to manage sustained power and
  # thermal limits. This complements power-profiles-daemon: PPD selects the
  # requested platform profile, while thermald keeps the CPU inside the
  # machine's adaptive thermal envelope.
  services.thermald.enable = true;

  # zram has a much lower access cost than filesystem or NVMe-backed swap.
  # Prefer reclaiming inactive anonymous pages into the high-priority zram
  # device before memory pressure causes interactive stalls. Disable swap
  # readahead because random zram faults do not benefit from fetching adjacent
  # pages. The encrypted physical swap remains the lower-priority fallback and
  # the hibernation target.
  boot.kernel.sysctl = {
    "vm.swappiness" = 180;
    "vm.page-cluster" = 0;
  };

  # Nix already defaults to all logical CPUs for parallel builds. Classify
  # those builds as non-interactive work and lower their best-effort I/O
  # priority so a large rebuild is less likely to make Plasma, audio, or the
  # browser unresponsive. This does not cap build parallelism.
  nix = {
    daemonCPUSchedPolicy = "batch";
    daemonIOSchedClass = "best-effort";
    daemonIOSchedPriority = 6;
  };
}
