# Performance design and extended checks

For a settings change, start with [the short performance guide](../PERFORMANCE.md).
This reference explains the implementation and measurement tradeoffs.

# Performance and responsiveness

1. Choose one policy below; edit its existing field in `/etc/nixos/settings.nix`.
2. Follow [apply a change](../install/customization.md); log out/in for Plasma policy changes.
3. Compare behavior using [power measurements](../POWER-MEASUREMENTS.md). Keep the change only if it helps your workload.

The configuration favors sustained laptop performance and desktop
responsiveness rather than benchmark-only kernel tweaks. It keeps all CPU
security mitigations enabled, respects firmware thermal limits, and applies configurable
power profiles when AC/battery state changes.

## Existing optimized baseline

The build already provides:

- the Framework Laptop 13 Pro Intel Core Ultra Series 3 hardware module;
- the latest pinned kernel, currently 7.2.8, above Framework's recommended
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
particular, no CPU frequency, IRQ affinity, or Nix job count is forced without
measurements from the installed machine. The Series 3 GPU is explicitly selected
for early initialization as described below.

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

### Measuring build and inference contention

`settings.builds.maxJobs` and `settings.builds.cores` expose the daemon's
parallelism controls. Both default to `null`, preserving NixOS defaults until
the installed laptop has been measured. `maxJobs` accepts a positive integer
or `"auto"`; `cores` accepts a nonnegative integer, with `0` meaning all cores.
The product can increase runnable work substantially: each concurrent build
can use the requested number of cores. These are scheduling hints, not hard
memory or CPU quotas for every build system.

Hyperfine and Intel turbostat are installed alongside the existing
`intel_gpu_top`, `btop`, `vmstat`, and `llama-bench`. Choose limits using this
repeatable procedure:

1. Record kernel, firmware, power profile, model/quantization, context length,
   browser workload and ambient conditions. Keep these fixed between runs.
2. Measure a representative uncached build alone, then with the same local
   inference workload. Cached builds measure fetching/activation, not compiler
   contention. Rebuilding just one derivation does not test job concurrency.
3. Compare defaults with candidate limits such as 2 jobs / 4 cores and 1 job /
   4 cores. These are experiments, not selected or measured recommendations.
   Set candidates in `settings.nix`, rebuild and confirm the daemon settings.
4. Repeat each case at least three times. Record build time, inference prompt
   and generation throughput, available RAM, swap activity, memory pressure,
   CPU temperature/power, fan noise and any audio underruns or desktop stalls.
5. Keep the fastest combination that preserves the responsiveness and memory
   headroom you need. Compare sustained AC `balanced` and `performance` runs,
   then separately measure a battery workload. Do not infer battery life from
   an AC-only benchmark.

Useful read-only observations during a run:

```bash
nix config show max-jobs
nix config show cores
powerprofilesctl get
vmstat 1
cat /proc/pressure/cpu /proc/pressure/memory /proc/pressure/io
sudo turbostat --quiet --interval 1 --num_iterations 60
```

Use `hyperfine --runs 5 'YOUR_REPRESENTATIVE_COMMAND'` for command timing;
substitute a real repeatable workload. Measure inference itself with
`llama-bench` and Ollama's response timing fields, not HTTP startup alone.
Follow the CPU/Vulkan comparison in [the AI guide](../LOCAL-AI-DEVELOPMENT.md).
No measurements on the target laptop are available yet, so no global compiler
flags, kernel scheduler replacements, or all-packages native-CPU rebuilds are
enabled. Keeping cached packages and runtime CPU/GPU dispatch avoids a large
source rebuild without evidence of a workload benefit.

### Optional home snapshots

Set `storage.homeSnapshots = true` to add a root-owned Btrfs snapshot subvolume
at `/home/.snapshots` and a Snapper home policy retaining 6 hourly and 3 daily
timeline snapshots, with no weekly/monthly/yearly retention. It is disabled
by default because Wine prefixes, development trees and local model downloads
can retain significant changed data. The counts are not disk-space quotas.

After activation, verify `sudo snapper -c home list` and create a test snapshot
with `sudo snapper -c home create --cleanup-algorithm number --description verification`.
Restore only selected files after reviewing them; do not roll back an active
home directory blindly. Disabling the option stops management, but does not
delete existing snapshots. This is local recovery, not an off-device backup.
Keep plaintext password exports out of snapshot coverage.

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
startup when needed. Ollaya is also available as an on-demand user service for
decision models, using the Intel CPU.

The shared `settings.ai` defaults give Continue an 8,192-token context and
2,048 generated tokens. Automatic tab completion, next-edit prediction, and
startup codebase indexing are disabled or paused, avoiding constant inference
while editing. Chat, edit, apply, and agent requests remain available on
demand. See `docs/LOCAL-AI-DEVELOPMENT.md` for setup and measured adjustment.

Running several large local model runtimes simultaneously is not an optimization
on a 32 GiB laptop unless measured resident memory leaves comfortable headroom
for Plasma and the browser. Ollama now defaults to one resident model and one
parallel request. See the AI guide for GPU-offload verification, CPU/Vulkan
benchmarks, Ollaya's Intel limitations and optional KV-cache quantization.

## Automatic AC and battery profiles

Plasma PowerDevil uses these `settings.nix` defaults at login and when the power
source or low-battery state changes:

| Power source | Profile |
| --- | --- |
| AC | `performance` |
| Battery | `balanced` |
| Low battery | `power-saver` |

Home Manager writes `PowerProfile` in the `[AC][Performance]`,
`[Battery][Performance]` and `[LowBattery][Performance]` groups of
`~/.config/powerdevilrc`. With the default sleep policy it also sets `SleepMode=3`, `LidAction=1`,
`PowerButtonAction=1` and `InhibitLidActionWhenExternalMonitorPresent=true` under
`[AC][SuspendAndShutdown]` and the corresponding Battery/LowBattery groups.
Plasma therefore uses suspend-then-hibernate for lid closure and the power
button, and suppresses lid suspension with an external monitor. Brightness,
auto-suspend action and idle timeout preferences remain unchanged; when the
idle action is Sleep, it uses this sleep mode too. These managed settings
replace previous GUI choices at activation. Log out/in after rebuilding to
load the policy. Plasma applies
this policy during your desktop session; it is not a console-only or pre-login
AC-switching service. PowerDevil's default low-battery threshold is 10%, unless
you have changed it in Plasma.

Change `power.acProfile` to `balanced` for cooler/quieter daily plugged-in use;
change `power.batteryProfile` to `power-saver` for a stronger battery preference.
GUI edits of the managed power-profile and sleep/lid choices are replaced on
the next Home Manager activation. Temporary manual selection remains available until another profile
transition or reload. Only select `performance` if `powerprofilesctl list`
reports it supported; if unavailable, configure `balanced` for AC.

This controls Intel's supported energy-performance and platform policy through
power-profiles-daemon. It does not need a second daemon writing raw governors.
With active `intel_pstate`, a `powersave` governor can still boost dynamically;
its name is not proof that the CPU is running at minimum speed. Avoid adding
TLP, auto-cpufreq or scripts that compete for the same controls.

Inspect or temporarily select a profile:

```bash
powerprofilesctl list
powerprofilesctl get
powerprofilesctl set performance
```

For a temporary cooler setting:

```bash
powerprofilesctl set balanced
```

If AC is configured as `balanced`, a command can hold `performance` for its
lifetime. Launching an Ollama CLI client alone does not scope the separate
server lifetime; stop inference when you finish:

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

## Selectable sleep policy

Edit the existing `power` block in `settings.nix`:

```nix
sleepMode = "suspend-then-hibernate"; # Or "suspend" or "hibernate".
hibernateDelayMinutes = 60;
hibernateOnAC = true;
```

These preserve the previous default: suspend followed by hibernation after
60 minutes, including on AC. A low battery may trigger hibernation earlier.
Set `hibernateOnAC = false` to start that countdown only after AC is disconnected.
The positive integer delay and AC policy apply only to suspend-then-hibernate;
they do not delay a direct hibernation request.

The chosen mode controls logind's lid/power-button actions and Plasma's matching
actions. Docked lid suspension remains suppressed. Plasma represents direct
hibernation as action 2, not sleep mode 2 (which means hybrid sleep). Existing
idle actions and timeouts remain yours: when choosing direct hibernation, also
select **Hibernate** as the automatic idle action in Plasma if wanted. For the
other two choices, an existing **Sleep** idle action follows the selected mode.
Log out/in after a rebuild so PowerDevil reloads these settings.

The encrypted 40 GiB physical swap and resume-device setup remain in place.
Check resume on the actual laptop before relying on unattended sleep. Follow
[repeatable overnight and resume checks](../POWER-MEASUREMENTS.md#sleep-and-resume).
No `mem_sleep_default=deep` workaround is added: only modes actually exposed by
`/sys/power/mem_sleep` are available on the machine.

## Targeted thermald update and diagnostics

The service uses pinned **thermald 2.5.13**, retaining adaptive firmware-table
control and the standard NixOS service/DBus setup. This updates only thermald,
with a fixed source hash, rather than changing the entire Nixpkgs baseline.
The [upstream release notes](https://github.com/intel/thermal_daemon/blob/v2.5.13/README.txt)
cover power-limit restoration and adaptive-control fixes. No measured throughput
or battery-life improvement is claimed. Check its journal and temperatures under
your sustained workloads; the previous NixOS generation remains the rollback.

`framework-power-report` provides a read-only JSON report and optional battery
sampling/GPU counters. It is installed even when local AI is disabled. See the
[power, browser decoding and sleep measurement guide](../POWER-MEASUREMENTS.md).
The optional [60 Hz battery preset](../DISPLAY.md#optional-battery-refresh-preset)
keeps the refresh/comfort tradeoff selectable.

## Xe graphics and modern video acceleration

The Series 3/Xe3 configuration now sets:

```nix
hardware.intelgpu = {
  driver = "xe";
  vaapiDriver = "intel-media-driver";
};
```

The pinned hardware module uses `driver` to load Xe in the initrd. It does not
add `force_probe` or blacklist i915. The modern VA-API selection removes legacy
i965 packages while retaining the modern media, Intel compute and VPL runtimes,
including the configured 32-bit media support. This is hardware-specific
cleanup and early graphics initialization, not a measured AI throughput gain.
Use `lspci -nnk` and `vainfo` after reboot to confirm the actual driver and codecs.

## Deferred maintenance on AC

`power.maintenanceOnAC = true` gates Nix garbage collection and Btrfs scrubbing
at service start. Their weekly/monthly schedules and upstream scrub
cancellation remain intact. A job triggered on battery writes a `deferred`
marker in `/var/lib/ac-maintenance`, then skips without a failure. Every 15
minutes (with up to one minute of timer coalescing), an AC-only retry service
starts jobs whose marker reads `deferred` or `interrupted`. Markers survive
reboot and clear only after successful completion. A job that was killed or
timed out is marked `interrupted` and retried on AC; a job that ran and exited
with an error is marked `failed` and waits for its next calendar run instead of
being relaunched every interval. No marker means no extra GC or scrub. Retried
scrubs start a fresh scrub using the upstream command.

Unplugging does not kill a job already running. This avoids interrupting GC and
preserves normal scrub lifecycle management. The retry timer does not wake a
sleeping laptop. A failed job stays visible in the journal and in its marker;
resolve the reported cause before its next calendar run. Nix-store optimization
already has an upstream AC condition and is not modified here.

```bash
systemctl list-timers ac-maintenance-retry.timer nix-gc.timer 'btrfs-scrub--.timer'
sudo ls -l /var/lib/ac-maintenance
journalctl -u nix-gc -u btrfs-scrub-- -u ac-maintenance-retry
```

Set `power.maintenanceOnAC = false` to restore upstream scheduling. Existing
pending markers are retained but not retried while disabled; re-enabling may
run that pending work on AC.

## Battery charge limit

`power.chargeLimit = 80` applies an 80% end-of-charge threshold at boot and when
the changed service is activated. It loads the already-packaged Framework
module, writes the supported `BAT*` sysfs interface, and checks its readback.
This favors battery longevity during plugged-in use; it reduces the charge
available for travel and does not force a battery above 80% to discharge.

```bash
systemctl status framework-charge-limit.service
cat /sys/class/power_supply/BAT*/charge_control_end_threshold
```

For travel, set `power.chargeLimit = 100` and rebuild. Set it to `null` to remove
the managed service and let firmware/Plasma control the limit. **Null does not
reset a limit already stored by firmware**: apply 100 first, or reset it in
Plasma/firmware. GUI changes can last until the service next runs. If the sysfs
interface is missing or the firmware rejects the value, the service fails with
a diagnostic; inspect its journal and Framework driver before trying again.

## Optional dock and Wi-Fi settings

`features.thunderbolt = true` enables Bolt's normal device-authorization
integration for Thunderbolt/USB4 docks that need it. It defaults to false and
adds no automatic authorization rules; it is not needed for every USB-C dock.
With it enabled, use `boltctl list` and Plasma's device authorization controls.

`network.wifiPowerSave` defaults to `null`. Set it to `false` only to disable
Wi-Fi power saving as a reliability workaround, or `true` to request power
saving. See [NETWORKING.md](../NETWORKING.md#optional-wi-fi-power-saving-override)
for application, verification and rollback.

## Verify on the installed laptop

After rebuilding and logging back into Plasma, check `powerprofilesctl get`
with the charger connected, then disconnected: expect `performance`, then
`balanced`. Inspect the underlying policy without modifying it:

```bash
cat /sys/devices/system/cpu/intel_pstate/status
cat /sys/devices/system/cpu/cpufreq/policy0/scaling_driver
cat /sys/devices/system/cpu/cpufreq/policy0/scaling_governor
cat /sys/devices/system/cpu/cpufreq/policy0/energy_performance_preference
```

These sysfs files depend on the active driver; do not force `intel_pstate` if
firmware or kernel reports a different configuration. Profile names need not
produce different `scaling_governor` strings: inspect EPP and actual behavior.
Also verify the effective components:

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
- force GPU binding with `force_probe` or blacklist drivers; selecting Xe for
  the initrd does not force hardware binding;
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

- [Plasma 6.6.6 power-profile schema](https://github.com/KDE/powerdevil/blob/v6.6.6/PowerDevilProfileSettings.kcfg)

- [Series 3 Xe and media-driver example](https://github.com/maxabbot/nix/blob/main/hosts/framework/default.nix)
- [Series 3 Xe and dock example](https://github.com/lanice/nixhome/blob/main/hosts/longjing/default.nix)
- [Framework kernel charge-limit interface](https://github.com/DHowett/framework-laptop-kmod#battery-charge-limit)
- [systemd ExecCondition and completion semantics](https://github.com/systemd/systemd/blob/v260/man/systemd.service.xml)
