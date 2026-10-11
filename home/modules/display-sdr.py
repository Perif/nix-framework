"""Apply SDR and optional AC/battery refresh policy through KScreen's live API."""

import argparse
import json
import math
import re
import subprocess
import sys


def refresh_change(output, target):
    """Select an advertised rate at the current resolution; never invent modes."""
    name = output["name"]
    modes = output.get("modes")
    if not isinstance(modes, list) or not all(isinstance(mode, dict) for mode in modes):
        raise ValueError(f"Invalid modes for {name}")
    current = next((mode for mode in modes if mode.get("id") == output.get("currentModeId")), None)
    if current is None or not isinstance(current.get("size"), dict):
        raise ValueError(f"Missing current mode for {name}")
    candidates = []
    for mode in modes:
        if mode.get("size") != current["size"]:
            continue
        rate = mode.get("refreshRate")
        mode_id = mode.get("id")
        # kscreen-doctor separates subcommands with dots; mode IDs are opaque.
        # Reject IDs that cannot be passed losslessly rather than changing modes.
        if (not isinstance(mode_id, str) or not re.fullmatch(r"[A-Za-z0-9_@:+-]+", mode_id)
                or type(rate) not in (int, float) or not math.isfinite(rate) or rate <= 0):
            raise ValueError(f"Invalid mode for {name}")
        if target == "highest" or abs(rate - target) <= 0.5:
            candidates.append(mode)
    if not candidates:
        print(f"No advertised {target} Hz mode at the current resolution for {name}; unchanged", file=sys.stderr)
        return []
    selected = max(candidates, key=lambda mode: mode["refreshRate"]) if target == "highest" else min(
        candidates, key=lambda mode: (abs(mode["refreshRate"] - target), mode["id"] != current["id"])
    )
    if selected["id"] == current["id"]:
        return []
    return [f"output.{name}.mode.{selected['id']}"]


def changes(config, disable_hdr=True, refresh_hz=None):
    outputs = config.get("outputs")
    if not isinstance(outputs, list):
        raise ValueError("KScreen did not return an outputs list")
    arguments = []
    for output in outputs:
        if not isinstance(output, dict):
            raise ValueError("KScreen returned an invalid output")
        name = output.get("name", "")
        if not isinstance(name, str) or not re.fullmatch(r"eDP-\d+", name):
            continue
        if output.get("connected") is not True or output.get("enabled") is not True:
            continue
        # libkscreen 6.6 serializes these fields only for supported controls.
        # WCG must also be off for KWin to apply the selected SDR ICC profile.
        for field in (("hdr", "wcg") if disable_hdr else ()):
            if field in output:
                if not isinstance(output[field], bool):
                    raise ValueError(f"Invalid {field} state for {name}")
                if output[field]:
                    arguments.append(f"output.{name}.{field}.disable")
        if disable_hdr and "edrPolicy" in output:
            policy = output["edrPolicy"]
            if type(policy) is not int or policy not in (0, 1):
                raise ValueError(f"Unknown EDR policy for {name}: {policy!r}")
            if policy != 0:  # KScreen::Output::EdrPolicy::Never
                arguments.append(f"output.{name}.edrPolicy.never")
        if refresh_hz is not None:
            arguments.extend(refresh_change(output, refresh_hz))
    return arguments


def enforce(doctor, disable_hdr=True, refresh_hz=None):
    def read_config():
        result = subprocess.run(
            [doctor, "--json"], check=True, capture_output=True, text=True, timeout=15
        )
        config = json.loads(result.stdout)
        if not isinstance(config, dict):
            raise ValueError("KScreen returned an invalid configuration")
        return config

    arguments = changes(read_config(), disable_hdr, refresh_hz)
    if not arguments:
        return
    subprocess.run([doctor, *arguments], check=True, timeout=15)
    if changes(read_config(), disable_hdr, refresh_hz):
        raise RuntimeError("KScreen did not apply the built-in display policy")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--doctor", required=True)
    parser.add_argument("--allow-hdr", action="store_true")
    parser.add_argument("--busctl")
    parser.add_argument("--battery-hz", type=int)
    parser.add_argument("--ac-hz", default="highest")
    args = parser.parse_args()
    try:
        target = None
        if args.battery_hz is not None:
            if not args.busctl:
                raise ValueError("Refresh policy requires --busctl")
            result = subprocess.run([
                args.busctl, "--system", "get-property", "org.freedesktop.UPower",
                "/org/freedesktop/UPower", "org.freedesktop.UPower", "OnBattery",
            ], check=True, capture_output=True, text=True, timeout=10)
            state = result.stdout.strip()
            if state not in ("b true", "b false"):
                raise ValueError("UPower did not return a boolean OnBattery value")
            target = args.battery_hz if state == "b true" else (
                "highest" if args.ac_hz == "highest" else int(args.ac_hz)
            )
        enforce(args.doctor, not args.allow_hdr, target)
    except (OSError, ValueError, RuntimeError, subprocess.SubprocessError) as error:
        if args.battery_hz is not None and not args.allow_hdr:
            # A missing UPower service or malformed mode list must not prevent
            # the independent SDR policy from being applied.
            try:
                enforce(args.doctor)
            except (OSError, ValueError, RuntimeError, subprocess.SubprocessError) as sdr_error:
                print(f"SDR fallback failed: {sdr_error}", file=sys.stderr)
        print(f"Built-in SDR policy failed: {error}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
