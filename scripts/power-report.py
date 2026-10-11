"""Read-only Framework power/sleep report; unavailable readings remain explicit."""

import argparse
from datetime import datetime, timezone
import json
from pathlib import Path
import platform
import signal
import subprocess
import time


def read(path):
    try:
        return path.read_text().strip()
    except (OSError, UnicodeError):
        return None


def number(path):
    try:
        return int(read(path))
    except (ValueError, TypeError):
        return None


def battery(path):
    status = read(path / "status")
    power = number(path / "power_now")
    source = "power_now"
    if power is None:
        current, voltage = number(path / "current_now"), number(path / "voltage_now")
        power = None if current is None or voltage is None else abs(current * voltage) / 1_000_000
        source = "current_now * voltage_now (estimate)"
    energy = number(path / "energy_now")
    return {
        "name": path.name,
        "status": status,
        "capacity_percent": number(path / "capacity"),
        "energy_wh": None if energy is None else energy / 1_000_000,
        "discharge_w": abs(power) / 1_000_000 if power is not None and status == "Discharging" else None,
        "power_source": source if power is not None else None,
        "charge_limit_percent": number(path / "charge_control_end_threshold"),
    }


def snapshot(sysfs):
    batteries = [battery(path) for path in sorted((sysfs / "class/power_supply").glob("*"))
                 if read(path / "type") == "Battery" and read(path / "scope") != "Device"
                 and read(path / "present") != "0"]
    total = sum(b["discharge_w"] for b in batteries) if batteries and all(
        b["discharge_w"] is not None for b in batteries
    ) else None
    return {
        "timestamp_utc": datetime.now(timezone.utc).isoformat(),
        "batteries": batteries,
        "total_battery_discharge_w": total,
        "note": "Battery-side whole-system reading while discharging; not CPU package power or wall power. null means unavailable, not zero.",
    }


def command(argv, timeout=10):
    try:
        result = subprocess.run(argv, capture_output=True, text=True, timeout=timeout)
        return {"returncode": result.returncode, "output": result.stdout.strip(), "error": result.stderr.strip()}
    except (OSError, subprocess.SubprocessError) as error:
        return {"returncode": None, "output": "", "error": str(error)}


def gpu_activity(seconds):
    try:
        process = subprocess.Popen(["intel_gpu_top", "-J", "-s", "1000"], stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
        try:
            out, err = process.communicate(timeout=seconds)
        except subprocess.TimeoutExpired:
            process.send_signal(signal.SIGINT)
            try:
                out, err = process.communicate(timeout=5)
            except subprocess.TimeoutExpired:
                process.kill()
                out, err = process.communicate()
        return {"returncode": process.returncode, "output": out, "error": err}
    except OSError as error:
        return {"returncode": None, "output": "", "error": str(error)}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--sample-seconds", type=int, default=0, choices=range(0, 3601), metavar="0..3600",
                        help="also take a second battery reading after this interval (default 0)")
    parser.add_argument("--gpu-seconds", type=int, default=0, choices=range(0, 31), metavar="0..30",
                        help="capture GPU engine counters; may require sudo (default 0)")
    args = parser.parse_args()
    sysfs = Path("/sys")
    report = {
        "schema_version": 1,
        "kernel": platform.release(),
        "firmware": {key: read(sysfs / "class/dmi/id" / key) for key in ("bios_version", "bios_date", "product_name")},
        "battery": snapshot(sysfs),
        "sleep": {key: read(sysfs / "power" / key) for key in ("state", "mem_sleep", "disk")},
        "residency_us": {key: read(sysfs / "devices/system/cpu/cpuidle" / key) for key in (
            "low_power_idle_cpu_residency_us", "low_power_idle_system_residency_us")},
        "suspend_stats": {path.name: read(path) for path in sorted((sysfs / "power/suspend_stats").glob("*"))},
        "cpu_policy": {key: read(sysfs / "devices/system/cpu/cpufreq/policy0" / key) for key in (
            "scaling_driver", "scaling_governor", "energy_performance_preference")},
        "power_profile": command(["powerprofilesctl", "get"]),
        "available_profiles": command(["powerprofilesctl", "list"]),
        "services": command(["systemctl", "show", "thermald.service", "power-profiles-daemon.service",
                             "-p", "Id", "-p", "ActiveState", "-p", "SubState", "-p", "ExecMainStatus"]),
        "thermald_version": command(["thermald", "--version"]),
        "temperatures": command(["sensors", "-j"]),
        "usb_topology": command(["lsusb", "-t"]),
    }
    # Bounded kernel logs, no application logs, serial inventory or process command
    # lines. No uploads, sudo, firmware refresh, or configuration writes.
    pattern = "(?i)(suspend|hibernate|resume|s2idle|BERT|selective fetch|GPU HANG|GPU reset)"
    report["kernel_sleep_graphics_log"] = command([
        "journalctl", "-k", "-b", "--no-pager", "-n", "80", "--grep", pattern,
    ])
    report["previous_boot_sleep_graphics_log"] = command([
        "journalctl", "-k", "-b", "-1", "--no-pager", "-n", "40", "--grep", pattern,
    ])
    if args.gpu_seconds:
        report["gpu_activity"] = gpu_activity(args.gpu_seconds)
    if args.sample_seconds:
        # Exclude the diagnostic commands' startup work from the sample window.
        before = snapshot(sysfs)
        start = time.clock_gettime(time.CLOCK_BOOTTIME)
        time.sleep(args.sample_seconds)
        after = snapshot(sysfs)
        elapsed = time.clock_gettime(time.CLOCK_BOOTTIME) - start
        old = {b["name"]: b for b in before["batteries"]}
        new = {b["name"]: b for b in after["batteries"]}
        valid = bool(old) and old.keys() == new.keys() and all(
            b["status"] == "Discharging" and b["energy_wh"] is not None for b in [*old.values(), *new.values()]
        )
        delta = sum(old[name]["energy_wh"] - new[name]["energy_wh"] for name in old) if valid else None
        report["sample"] = {"before": before, "after": after, "elapsed_seconds": elapsed,
                            "average_discharge_w": delta * 3600 / elapsed if delta is not None and delta >= 0 else None,
                            "note": "Energy-counter estimate; keep AC disconnected throughout. Short intervals can be below sensor resolution."}
    print(json.dumps(report, indent=2))


if __name__ == "__main__":
    main()
