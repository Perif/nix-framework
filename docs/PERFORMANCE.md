# Configure power and performance

Change one policy at a time. Edit existing fields in `/etc/nixos/settings.nix`,
follow [apply a change](install/customization.md), then verify the result below.
Log out/in after Plasma policy changes. Keep defaults until measurements justify
an adjustment; no laptop throughput or battery-life improvement is assumed.

## Automatic AC and battery profiles

| Setting | Default | Common alternative |
| --- | --- | --- |
| `power.acProfile` | `"performance"` | `"balanced"` for a cooler/quieter AC preference |
| `power.batteryProfile` | `"balanced"` | `"power-saver"` for a stronger battery preference |
| `power.lowBatteryProfile` | `"power-saver"` | Keep unless you have a measured reason to change |

1. Run `powerprofilesctl list`; use only profiles the hardware reports.
2. Edit the desired field, apply the change, then log out/in.
3. Run `powerprofilesctl get` with AC connected, then disconnected.

**Expected:** your selected AC and battery profiles. Switching is managed by
Plasma during the desktop session. Managed GUI profile choices are replaced at
activation; brightness and idle timeouts remain user-owned.

This controls Intel's supported energy/performance policy through
power-profiles-daemon. Under active `intel_pstate`, a `powersave` governor can
still boost. Do not add TLP, auto-cpufreq or a second governor-writing daemon.
For a temporary comparison use `powerprofilesctl set balanced` or, if supported,
`powerprofilesctl set performance`; a later source transition can replace it.

## Selectable sleep policy

| Setting | Default | Alternatives |
| --- | --- | --- |
| `power.sleepMode` | `"suspend-then-hibernate"` | `"suspend"`, `"hibernate"` |
| `power.hibernateDelayMinutes` | `60` | Positive integer; combined mode only |
| `power.hibernateOnAC` | `true` | `false` starts the combined-mode countdown after AC disconnects |

1. Change the existing fields, apply, then log out/in.
2. Save work and test the selected sleep mode from the power menu.
3. Verify resume, lock screen, Wi-Fi and audio; use the
   [sleep measurement procedure](POWER-MEASUREMENTS.md#sleep-and-resume).

The mode manages lid and power-button actions; docked lid suspension remains
inhibited. For automatic idle hibernation, also choose **Hibernate** as the idle
action in Plasma. Existing **Sleep** idle actions follow the selected suspend
mode. Low battery can trigger hibernation earlier. Do not rely on unattended
sleep until the laptop passes resume tests.

## Battery charge limit

1. Keep `power.chargeLimit = 80` for the default limit, or set `100` before travel.
2. Apply the change and check:

```bash
systemctl status framework-charge-limit.service
cat /sys/class/power_supply/BAT*/charge_control_end_threshold
```

**Expected:** successful service and matching threshold. It does not force a
battery above the threshold to discharge. If the interface is missing or rejects
the value, inspect the service journal rather than forcing a write.

To stop management, apply `100` first if you want full charge, then set `null`
and rebuild. **Null does not reset a threshold already stored in firmware.**

## Measuring build and inference contention

`builds.maxJobs` and `builds.cores` default to `null`, preserving NixOS defaults.
`maxJobs` accepts a positive integer or `"auto"`; `cores` accepts a nonnegative
integer (`0` means all cores). These are build scheduling hints, not memory quotas.

1. Record firmware/kernel, power profile, model/quantization, context and workload.
2. Measure a representative **uncached** multi-derivation build alone and with
   the same inference task. Cached builds do not measure compiler contention.
3. Compare defaults against experimental candidates such as 2 jobs / 4 cores,
   then 1 job / 4 cores. Edit the fields, apply and verify:

```bash
nix config show max-jobs
nix config show cores
powerprofilesctl get
```

4. Repeat each case at least three times. Record build time, inference throughput,
   RAM, swap, temperatures and desktop/audio stalls. Use `btop`, `vmstat 1` and
   `/proc/pressure/{cpu,memory,io}`; stop continuous monitors with `Ctrl-C`.
5. Keep the fastest candidate that preserves your required memory headroom and
   responsiveness. Measure battery workloads separately from AC.

For detailed counters and CPU/Vulkan comparisons, use
[build measurements](reference/performance-design.md#measuring-build-and-inference-contention)
and [AI benchmarks](reference/ai-backends.md).

## Deferred maintenance on AC

Keep `power.maintenanceOnAC = true` to defer GC and Btrfs scrub starts on battery.
Already-running jobs continue. Deferred/interrupted jobs retry on AC every
15 minutes; jobs that fail normally wait for their next scheduled run.

After applying a change, inspect:

```bash
systemctl list-timers ac-maintenance-retry.timer nix-gc.timer 'btrfs-scrub--.timer'
journalctl -u nix-gc -u btrfs-scrub-- -u ac-maintenance-retry
```

Set `false` to restore upstream scheduling. Pending markers remain and may be
retried after re-enabling the policy. Investigate failed jobs before retrying.

## Optional home snapshots

1. Set `storage.homeSnapshots = true` and apply the change.
2. Verify `sudo snapper -c home list`.
3. Keep an off-device backup; local snapshots are not one.

Retention is 6 hourly and 3 daily timeline snapshots, not a space quota.
Downloads, Wine prefixes and developer trees can retain significant data.
Disabling the setting does not delete snapshots. Keep plaintext password exports
outside snapshot coverage and restore individual reviewed files, not a live home
subvolume blindly.

## Optional dock and Wi-Fi settings

- Set `features.thunderbolt = true` only for a dock that needs Bolt authorization.
  Apply, then inspect `boltctl list` and authorize the intended device in Plasma.
  No automatic authorization is added.
- `network.wifiPowerSave = null` keeps the default; `false` disables saving;
  `true` requests saving. Follow [Wi-Fi apply/verify steps](NETWORKING.md#optional-wi-fi-power-saving-override).
- For independent AC and battery refresh rates, follow
  [display policy](DISPLAY.md#optional-battery-refresh-preset).

## Verify on the installed laptop

```bash
framework-power-report > power-baseline.json
systemctl is-active thermald.service
vulkaninfo --summary
vainfo
```

Review the local report before sharing it; device identifiers may be present.
Missing sensors are reported as unavailable. Use [measurements](POWER-MEASUREMENTS.md)
to verify browser decoding, power transitions and sleep on this machine.

## Implementation reference

The existing defaults include adaptive thermald, Xe/modern Intel media support,
zram and lower-priority Nix builds. Their rationale and extended checks are in
[performance design](reference/performance-design.md). No blanket native-CPU
rebuild, competing power daemon or unsupported deep-sleep override is enabled.
