# Power, browser decoding and sleep measurements

The installed `framework-power-report` command gathers local, read-only JSON:

```bash
framework-power-report > power-baseline.json
framework-power-report --sample-seconds 300 > battery-idle.json
sudo framework-power-report --gpu-seconds 5 > gpu-video.json
```

The first command needs no root access. The GPU option may need root for Intel
performance counters; the command never invokes sudo itself. Missing tools,
permissions and sensors remain explicit errors or `null`, never an invented
zero. No report is uploaded and no firmware, sysfs or service setting is changed.
The report includes BIOS/kernel versions, thermald version/status, active and
available power profiles, temperatures, USB topology, available sleep modes,
suspend statistics and bounded current/previous-boot sleep/graphics logs.
Kernel logs can contain device identifiers; review the file before sharing it.

`total_battery_discharge_w` is the battery's whole-laptop discharge rate,
including attached bus-powered devices; it is not CPU package power or wall
power. On AC, battery charging/full readings cannot establish total consumption
and are reported as `null`. Current-times-voltage fallbacks are labeled estimates.
Optional samples estimate average watts from energy loss over elapsed time;
keep AC disconnected throughout. Short intervals may fall below sensor precision.
Energy-counter averages remain unavailable if firmware only exposes charge.

Keep screen brightness, refresh rate, applications, network conditions and
battery profile consistent. After login/builds settle, compare at least five
minutes of idle, the same video, a representative development workload and an
AI workload separately. Repeat meaningful comparisons. Temperature, fan noise,
responsiveness and audio continuity matter alongside watts or throughput.
Disconnect the DC-Elite, dock and expansion peripherals, then reconnect them one
at a time to measure their effect. Do not apply blanket USB autosuspend changes
to an audio device without checking playback and resume reliability.

## Firefox hardware decoding

1. Open `about:support` in the installed Firefox profile. Check the window
   protocol is Wayland, the compositor is WebRender, and inspect the Media codec
   support/decision information. Field names vary by Firefox version.
2. Run `vainfo` to check driver codec availability. This alone does not prove
   that Firefox actually uses hardware decoding.
3. Play a known local or streamed video with a codec/resolution the driver
   supports. With other video applications closed, inspect `sudo intel_gpu_top`:
   look for activity in the Video engine during playback, then compare paused
   playback. `sudo framework-power-report --gpu-seconds 5` can save a short trace.
4. Compare battery power under the same video, brightness and refresh settings.
   DRM, streaming codec selection and unsupported codecs can change the result.
   GPU counters corroborate activity; they do not by themselves identify which
   process is using the decoder.

Firefox's normal hardware-acceleration selection remains enabled. Avoid random
forced preferences or disabling its sandbox to make a diagnostic look better.
See [Mozilla's performance settings](https://support.mozilla.org/en-US/kb/performance-settings)
and the [recent Framework browser-power discussion](https://www.reddit.com/r/framework/comments/1wqu6xy/framework_13_pro_new_to_fedora_44_kde_any_tips_on/).
These reports motivate verification, not a claim that a particular browser
will always use less power on this laptop.

## Sleep and resume

1. Save work and verify the configured action/delay with
   `systemd-analyze cat-config systemd/sleep.conf`. Run `swapon --show` to confirm
   the encrypted physical swap is present.
2. Capture `framework-power-report > before-sleep.json`, unplug power, and test
   one short lid-close/resume cycle before an unattended overnight test. Test
   direct hibernation separately with `systemctl hibernate` after saving work.
3. For suspend-then-hibernate, leave it asleep past the configured delay, then
   resume and capture `framework-power-report > after-sleep.json`. Compare the
   battery `energy_wh` values and elapsed UTC time. The average loss in watts
   is `(before Wh - after Wh) / elapsed hours`; repeat because firmware readings
   have limited precision.
4. Inspect `journalctl -b -u systemd-suspend-then-hibernate.service` and
   `journalctl -b -u systemd-hibernate.service`. After an unexpected reboot,
   inspect `journalctl -b -1 -k`; the report includes a bounded filtered extract.
   Record whether wakeup restored the session, reset the machine, or cold-booted.
5. Repeat short cycles and an overnight test with and without the dock, then
   check Wi-Fi, display refresh, speakers and DC-Elite playback after resume.

Where exported, the report includes cumulative CPU and system low-power idle
residency counters. Compare deltas over the same interval; CPU C10 residency is
not proof of system S0ix residency. Unavailable counters are not evidence of a
failure. See the [kernel LPIT documentation](https://docs.kernel.org/firmware-guide/acpi/lpit.html).

The [matching Panther Lake suspend report](https://community.frame.work/t/fw13-pro-suspend-then-hibernate-system-crash-possible-firmware-issue-s2idle-resume-platform-resets-panther-lake-bios-3-02/84960)
is a diagnostic lead, not a confirmed defect affecting every laptop. Use the
selectable sleep policy in [PERFORMANCE.md](PERFORMANCE.md#selectable-sleep-policy)
if testing reveals a problem. Keep a known-working boot generation. Do not force
S3/deep sleep unless firmware actually exposes it, or disable PSR based on an
older/AMD model's workaround.
