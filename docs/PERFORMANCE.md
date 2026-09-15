# Performance and responsiveness

The configuration favors sustained laptop performance and desktop
responsiveness rather than benchmark-only kernel tweaks. It keeps all CPU
security mitigations enabled, respects firmware thermal limits, and leaves the
power profile under explicit user control.

## Existing optimized baseline

The build already provides:

- the Framework Laptop 13 Pro Intel Core Ultra Series 3 hardware module;
- the latest pinned kernel, currently 7.2.3, above Framework's recommended
  kernel level for this generation;
- Intel microcode plus Mesa, Vulkan, VA-API, OneVPL, and Intel compute runtimes
  supplied by `nixos-hardware`;
- power-profiles-daemon integration with Plasma;
- Nix build parallelism across all available logical CPUs;
- Btrfs `zstd:3` compression and `noatime` mounts;
- weekly TRIM instead of synchronous discard on every filesystem operation;
- an 8 GiB logical zram device with higher priority than encrypted NVMe swap;
- weekly Nix-store deduplication outside the package-install critical path.

Those existing defaults are not duplicated in the local modules. In
particular, no CPU governor, Intel GPU driver, IRQ affinity, or Nix job count is
forced without measurements from the installed machine.

## Added optimizations

### Adaptive Intel thermal management

`services.thermald.enable = true` runs thermald in adaptive mode. It consumes
the platform's Intel DPTF tables and manages sustained power within the
firmware-defined thermal envelope. It complements power-profiles-daemon rather
than replacing the user-selectable `power-saver`, `balanced`, and `performance`
profiles.

The pinned thermald 2.5.11 includes Panther Lake support and the subsequent
Panther Lake DPTF-path correction. Do not set `ignoreCpuidCheck = true` if the
service rejects the machine: inspect the logs and update the pinned package or
disable thermald instead of forcing an unsupported thermal policy.

### Compressed-memory behavior

The zram device remains capped at 25% of 32 GiB RAM, or 8 GiB logical capacity,
and retains priority 100 over the physical swap device. Two VM settings make
that existing device useful before the desktop enters severe memory pressure:

```nix
boot.kernel.sysctl = {
  "vm.swappiness" = 180;
  "vm.page-cluster" = 0;
};
```

Linux defines swappiness as a relative I/O-cost scale from 0 to 200 and
explicitly permits values above 100 for in-memory or hybrid swap. A value of
180 strongly prefers low-latency zram for cold anonymous pages. Disabling swap
readahead avoids fetching adjacent pages on random zram faults.

This is workload-dependent. If measurements show excessive compression CPU
time or paging during the direct-ALSA audio workload, reduce swappiness to 100
in `modules/nixos/performance.nix`, rebuild with `test`, and compare again:

```nix
"vm.swappiness" = 100;
```

Do not remove the encrypted physical swap: it is the hibernation target and the
fallback after zram fills.

### Responsive Nix builds

Nix already defaults to `max-jobs = auto` and `cores = 0`, so builds may use all
logical CPUs. The configuration keeps that throughput but classifies daemon
work as batch CPU traffic and assigns it a lower best-effort I/O priority:

```nix
nix = {
  daemonCPUSchedPolicy = "batch";
  daemonIOSchedClass = "best-effort";
  daemonIOSchedPriority = 6;
};
```

This favors Plasma, audio, and browser I/O when a large local build is running.
It may make the build itself slightly slower while the laptop is busy with
interactive work; that is an intentional responsiveness tradeoff, not a claim
of higher peak compilation throughput.

### Bounded Ghostty surface memory

Each Ghostty tab, split, or window has its own in-memory scrollback and image
storage. The declarative profile limits scrollback to 8 MiB and keeps inline
image support with a 64 MiB limit for each primary or alternate screen buffer:

```nix
"scrollback-limit" = 8388608;
"image-storage-limit" = 67108864;
```

Ghostty maintains separate image limits for the primary and alternate screen,
so a single surface can retain up to roughly 128 MiB of image data in the worst
case. The previous upstream default allowed 320 MB for each screen buffer. Both
limits are lazy rather than immediate allocations. New scrollback limits apply
to newly created surfaces; restart Ghostty after rebuilding for a clean test.

On the installed laptop, inspect the effective configuration:

```bash
ghostty +show-config | grep -E \
  '^(scrollback-limit|image-storage-limit)'
```

Set `image-storage-limit` to `0` later only if disabling Kitty and other inline
image protocols is acceptable.

### Editor indexing and language-tool boundaries

VSCodium file watching/search and Sublime indexing exclude high-churn generated
trees: `.direnv`, `.venv`, `node_modules`, Nix `result`, and Rust `target`.
VSCodium also avoids watching Git object storage. This reduces wakeups, memory,
and duplicate indexing without hiding normal source files from Git or language
servers. Remove an exclusion only for a project that intentionally edits or
searches generated content.

BasedPyright defaults to open-file diagnostics, and Continue's startup index,
tab completion, and next-edit prediction remain paused. Go static analysis and
Rust Clippy run only while their language servers are active for matching files.
Vim and Neovim use one lightweight EditorConfig plug-in and otherwise built-in
editing features. Sublime uses one generic LSP client with Nix-managed servers
rather than separate plug-ins that each bundle and update their own runtimes.

These choices reduce idle work; they do not turn off correctness checks. Run
project CI, `ruff check`, `golangci-lint run`, and `cargo clippy` before delivery
according to the repository's own policy.

## Local AI development profile

Ollama and llama.cpp use the Vulkan path, and neither starts an inference server
at boot. Ollama retains its loopback-only, systemd-sandboxed service definition
but must be started with `ollama-on` and stopped with `ollama-off`. llama.cpp is
a user-started process. This prevents an unused local-model daemon from
occupying memory or exposing an idle HTTP parser, while retaining one-command
startup when needed.

The VSCodium Continue profile limits each request to an 8,192-token context and
2,048 generated tokens. Automatic tab completion, next-edit prediction, and
startup codebase indexing are disabled or paused, avoiding constant inference
while editing. Chat, edit, apply, and agent requests remain available on
demand. See `docs/LOCAL-AI-DEVELOPMENT.md` for setup and measured adjustment.

On AC power, a sustained local inference or compilation session can use the
temporary performance-profile command below. Daily editing should remain on
`balanced`. Running Ollama and a large llama.cpp server simultaneously is not
an optimization on a 32 GiB laptop unless measured resident memory leaves
comfortable headroom for Plasma and the browser. Stop Ollama after the session
instead of leaving it active merely because it has unloaded the model.

## Select performance only when needed

Keep `balanced` as the daily profile and use Plasma's power control or
`powerprofilesctl` when a plugged-in workload needs the larger thermal and
power budget:

```bash
powerprofilesctl list
powerprofilesctl get
powerprofilesctl set performance
```

Return to the balanced profile afterward:

```bash
powerprofilesctl set balanced
```

For one command, hold the performance profile only for that process lifetime:

```bash
powerprofilesctl launch \
  --profile performance \
  --reason "local build" \
  --appid local.nix-build \
  -- nix build .#REPLACE_WITH_OUTPUT
```

The performance profile may be unavailable or reported as degraded when the
platform driver, temperature, charger, or safety state does not permit it. Do
not override that condition with a forced CPU frequency.

## Verify on the installed laptop

After rebuilding and rebooting, verify the effective components:

```bash
uname -r
systemctl is-active thermald.service
journalctl -b -u thermald.service --no-pager
powerprofilesctl list
powerprofilesctl get
sysctl vm.swappiness vm.page-cluster
zramctl
swapon --show
vainfo
clinfo --list
systemctl show nix-daemon.service \
  -p CPUSchedulingPolicy \
  -p IOSchedulingClass \
  -p IOSchedulingPriority
nix config show max-jobs
nix config show cores
ghostty +show-config | grep -E \
  '^(scrollback-limit|image-storage-limit)'
codium --list-extensions
command -v basedpyright ruff gopls rust-analyzer
```

Expected values are `vm.swappiness = 180`, `vm.page-cluster = 0`, zram priority
100, CPU scheduling policy `batch`, and best-effort Nix I/O priority 6. The
physical swap must still be present at lower priority. Ghostty should report an
8,388,608-byte scrollback limit and a 67,108,864-byte image-storage limit.

Run real workloads in both `balanced` and `performance` profiles. Compare task
completion time, responsiveness, package temperature, fan noise, and battery
drain; a setting that raises a short benchmark but causes earlier thermal
throttling is not an improvement in sustained use.

## Deliberately excluded tweaks

The build does not:

- disable CPU vulnerability mitigations;
- force a CPU frequency or keep the performance profile active on battery;
- force the `i915` or `xe` driver beyond the current hardware-module default;
- enable an experimental `sched_ext`, Ananicy, or vendor-specific scheduler;
- force IRQ affinity without device-specific measurements;
- enable Btrfs autodefrag on the mixed development, Nix-store, and model-file
  workload;
- enable `tmpfs` for `/tmp`, which could compete with local AI models for RAM;
- enable the Intel NPU merely for Ollama or llama.cpp, which currently use the
  configured Vulkan GPU path rather than that NPU runtime.

These remain candidates only when a measured workload and a rollback test
justify them.

## Primary references

- [Framework Laptop 13 Pro Linux compatibility](https://frame.work/laptop13pro?tab=linux)
- [Framework power-profile guidance](https://knowledgebase.frame.work/en_us/optimizing-ubuntu-battery-life-Sye_48Lg3)
- [Intel thermal daemon](https://github.com/intel/thermal_daemon)
- [Linux VM sysctl documentation](https://www.kernel.org/doc/html/latest/admin-guide/sysctl/vm.html)
- [Power Profiles daemon](https://upower.pages.freedesktop.org/power-profiles-daemon/)
- [Linux Intel P-state documentation](https://www.kernel.org/doc/html/latest/admin-guide/pm/intel_pstate.html)
