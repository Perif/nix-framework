"""Keep enabled built-in eDP panels in SDR through KScreen's live API."""

import argparse
import json
import re
import subprocess
import sys


def changes(config):
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
        for field in ("hdr", "wcg"):
            if field in output:
                if not isinstance(output[field], bool):
                    raise ValueError(f"Invalid {field} state for {name}")
                if output[field]:
                    arguments.append(f"output.{name}.{field}.disable")
        if "edrPolicy" in output:
            policy = output["edrPolicy"]
            if type(policy) is not int or policy not in (0, 1):
                raise ValueError(f"Unknown EDR policy for {name}: {policy!r}")
            if policy != 0:  # KScreen::Output::EdrPolicy::Never
                arguments.append(f"output.{name}.edrPolicy.never")
    return arguments


def enforce(doctor):
    def read_config():
        result = subprocess.run(
            [doctor, "--json"], check=True, capture_output=True, text=True, timeout=15
        )
        config = json.loads(result.stdout)
        if not isinstance(config, dict):
            raise ValueError("KScreen returned an invalid configuration")
        return config

    arguments = changes(read_config())
    if not arguments:
        return
    subprocess.run([doctor, *arguments], check=True, timeout=15)
    if changes(read_config()):
        raise RuntimeError("KScreen did not apply the built-in SDR policy")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--doctor", required=True)
    args = parser.parse_args()
    try:
        enforce(args.doctor)
    except (OSError, ValueError, RuntimeError, subprocess.SubprocessError) as error:
        print(f"Built-in SDR policy failed: {error}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
