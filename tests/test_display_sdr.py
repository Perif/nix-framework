"""Exercise SDR enforcement with a stateful KScreen command fixture."""

import argparse
import copy
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest


parser = argparse.ArgumentParser()
parser.add_argument("--script", type=Path, default=Path(__file__).resolve().parents[1] / "home/modules/display-sdr.py")
ARGS, TEST_ARGS = parser.parse_known_args()

PANEL = {
    "name": "eDP-2", "connected": True, "enabled": True,
    "hdr": True, "wcg": True, "edrPolicy": 1,
    "iccProfilePath": "/home/test/.local/share/color/icc/custom.icc",
    "scale": 1.5, "currentModeId": "2880x1920@120", "brightness": 0.4,
    "pos": {"x": 0, "y": 0},
}
MODES = [
    {"id": "1", "size": {"width": 2880, "height": 1920}, "refreshRate": 120.0},
    {"id": "2", "size": {"width": 2880, "height": 1920}, "refreshRate": 59.94},
    {"id": "3", "size": {"width": 1920, "height": 1280}, "refreshRate": 60.0},
]


class DisplaySdr(unittest.TestCase):
    def setUp(self):
        temp = tempfile.TemporaryDirectory()
        self.addCleanup(temp.cleanup)
        self.root = Path(temp.name)
        self.state = self.root / "state.json"
        self.calls = self.root / "calls.jsonl"
        self.doctor = self.root / "kscreen-doctor"
        self.doctor.write_text(f"#!{sys.executable}\n" + '''
import json, os, sys
from pathlib import Path
state = Path(os.environ["TEST_DISPLAY_STATE"])
args = sys.argv[1:]
with open(os.environ["TEST_DISPLAY_CALLS"], "a") as log:
    log.write(json.dumps(args) + "\\n")
mode = os.environ.get("TEST_DISPLAY_FAILURE")
if mode == "query":
    sys.exit(2)
if args == ["--json"]:
    print(state.read_text())
    sys.exit(0)
if mode == "apply":
    sys.exit(3)
if mode == "ignored":
    sys.exit(0)
data = json.loads(state.read_text())
for arg in args:
    prefix, name, key, value = arg.split(".")
    assert prefix == "output"
    output = next(o for o in data["outputs"] if o["name"] == name)
    if key == "mode":
        assert value in [mode["id"] for mode in output["modes"]]
        output["currentModeId"] = value
    else:
        assert (key, value) in [("hdr", "disable"), ("wcg", "disable"), ("edrPolicy", "never")]
        output[key] = 0 if key == "edrPolicy" else False
state.write_text(json.dumps(data))
''')
        self.doctor.chmod(0o700)
        self.busctl = self.root / "busctl"
        self.busctl.write_text(f"#!{sys.executable}\nimport os\nprint(os.environ['TEST_ON_BATTERY'])\n")
        self.busctl.chmod(0o700)

    def run_policy(self, data, failure="", refresh=False, on_battery="b true", allow_hdr=False):
        self.state.write_text(json.dumps(data))
        self.calls.write_text("")
        result = subprocess.run(
            [sys.executable, str(ARGS.script), "--doctor", str(self.doctor)]
            + (["--busctl", str(self.busctl), "--battery-hz", "60"] if refresh else [])
            + (["--allow-hdr"] if allow_hdr else []),
            capture_output=True, text=True,
            env=os.environ | {
                "TEST_DISPLAY_STATE": str(self.state),
                "TEST_DISPLAY_CALLS": str(self.calls),
                "TEST_DISPLAY_FAILURE": failure,
                "TEST_ON_BATTERY": on_battery,
            },
        )
        return result, json.loads(self.state.read_text()), [json.loads(line) for line in self.calls.read_text().splitlines()]

    def test_refresh_switches_on_battery_and_ac_preserving_other_outputs_and_settings(self):
        panel = PANEL | {"currentModeId": "1", "modes": MODES}
        external = panel | {"name": "DP-1"}
        result, data, _ = self.run_policy({"outputs": [panel, external]}, refresh=True)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(data["outputs"], [panel | {"currentModeId": "2", "hdr": False, "wcg": False, "edrPolicy": 0}, external])
        result, data, calls = self.run_policy(data, refresh=True)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(calls, [["--json"]])
        result, data, _ = self.run_policy(data, refresh=True, on_battery="b false")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(data["outputs"][0]["currentModeId"], "1")
        self.assertEqual(data["outputs"][1], external)

    def test_refresh_can_run_without_enforcing_sdr(self):
        panel = PANEL | {"currentModeId": "1", "modes": MODES}
        result, data, _ = self.run_policy({"outputs": [panel]}, refresh=True, allow_hdr=True)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(data["outputs"][0], panel | {"currentModeId": "2"})

    def test_unsupported_refresh_never_changes_resolution(self):
        panel = PANEL | {"currentModeId": "1", "modes": [MODES[0], MODES[2]]}
        result, data, _ = self.run_policy({"outputs": [panel]}, refresh=True)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(data["outputs"][0]["currentModeId"], "1")
        self.assertIn("No advertised", result.stderr)

    def test_upower_failure_still_enforces_sdr_without_guessing_power_source(self):
        panel = PANEL | {"currentModeId": "1", "modes": MODES}
        result, data, _ = self.run_policy({"outputs": [panel]}, refresh=True, on_battery="unknown")
        self.assertNotEqual(result.returncode, 0)
        self.assertEqual(data["outputs"][0], panel | {"hdr": False, "wcg": False, "edrPolicy": 0})

    def test_only_active_internal_panel_changes_and_reapplication_is_read_only(self):
        external = PANEL | {"name": "DP-1"}
        closed = PANEL | {"name": "eDP-1", "enabled": False}
        unplugged = PANEL | {"name": "eDP-3", "connected": False}
        data = {"outputs": [PANEL, external, closed, unplugged]}
        expected = copy.deepcopy(data)
        expected["outputs"][0].update(hdr=False, wcg=False, edrPolicy=0)
        result, actual, calls = self.run_policy(data)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(actual, expected)
        self.assertEqual(len(calls), 3)  # Read, apply once, verify.
        result, actual, calls = self.run_policy(actual)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(actual, expected)
        self.assertEqual(calls, [["--json"]])

    def test_edr_is_disabled_on_an_sdr_panel_without_hdr_capability(self):
        panel = {key: value for key, value in PANEL.items() if key not in ("hdr", "wcg")}
        result, actual, calls = self.run_policy({"outputs": [panel]})
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(actual["outputs"][0], panel | {"edrPolicy": 0})
        self.assertEqual(calls[1], ["output.eDP-2.edrPolicy.never"])

    def test_unsupported_controls_or_external_only_session_are_noops(self):
        for output in [PANEL | {"name": "HDMI-A-1"}, {"name": "eDP-1", "connected": True, "enabled": True}]:
            with self.subTest(output=output):
                result, actual, calls = self.run_policy({"outputs": [output]})
                self.assertEqual(result.returncode, 0, result.stderr)
                self.assertEqual(actual, {"outputs": [output]})
                self.assertEqual(calls, [["--json"]])

    def test_errors_and_silently_ignored_changes_are_reported(self):
        for failure in ("query", "apply", "ignored"):
            with self.subTest(failure=failure):
                result, actual, _ = self.run_policy({"outputs": [PANEL]}, failure)
                self.assertNotEqual(result.returncode, 0)
                self.assertIn("Built-in SDR policy failed", result.stderr)
                self.assertEqual(actual, {"outputs": [PANEL]})

    def test_unknown_schema_does_not_write_anything(self):
        for data in ({}, [], {"outputs": [None]}, {"outputs": [PANEL | {"edrPolicy": 2}]}, {"outputs": [PANEL | {"hdr": "yes"}]}):
            with self.subTest(data=data):
                result, actual, calls = self.run_policy(data)
                self.assertNotEqual(result.returncode, 0)
                self.assertEqual(actual, data)
                self.assertEqual(calls, [["--json"]])


if __name__ == "__main__":
    unittest.main(argv=[sys.argv[0], *TEST_ARGS])
