{
  config,
  lib,
  pkgs,
  settings,
  ...
}:

{
  assertions = [
    {
      assertion =
        settings.builds.maxJobs == null
        || settings.builds.maxJobs == "auto"
        || (builtins.isInt settings.builds.maxJobs && settings.builds.maxJobs > 0);
      message = "builds.maxJobs must be null, auto, or a positive integer.";
    }
    {
      assertion =
        settings.builds.cores == null
        || (builtins.isInt settings.builds.cores && settings.builds.cores >= 0);
      message = "builds.cores must be null or a nonnegative integer (0 means all cores).";
    }
  ];
  environment.systemPackages = [
    config.boot.kernelPackages.turbostat
    (import ../../pkgs/power-report.nix { inherit pkgs; })
  ];
  # Use the firmware-provided Intel DPTF tables to manage sustained power and
  # thermal limits. This complements power-profiles-daemon: PPD selects the
  # requested platform profile, while thermald keeps the CPU inside the
  # machine's adaptive thermal envelope.
  services.thermald.enable = true;
  services.thermald.package = pkgs.callPackage ../../pkgs/thermald.nix { };

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
  # browser unresponsive. Optional limits below complement scheduling priority.
  nix = {
    daemonCPUSchedPolicy = "batch";
    daemonIOSchedClass = "best-effort";
    daemonIOSchedPriority = 6;
    settings =
      lib.optionalAttrs (settings.builds.maxJobs != null) {
        max-jobs = settings.builds.maxJobs;
      }
      // lib.optionalAttrs (settings.builds.cores != null) {
        cores = settings.builds.cores;
      };
  };
}
