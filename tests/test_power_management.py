"""Exercise the production helpers against fake power checks and battery sysfs."""

import argparse
import os
from pathlib import Path
import subprocess
import tempfile
import unittest


ROOT = Path(__file__).resolve().parents[1]
parser = argparse.ArgumentParser()
parser.add_argument("--maintenance", type=Path, default=ROOT / "modules/nixos/scripts/ac-maintenance.sh")
parser.add_argument("--charge", type=Path, default=ROOT / "modules/nixos/scripts/charge-limit.sh")
ARGS, TEST_ARGS = parser.parse_known_args()


class PowerHelpers(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.marker = self.root / "scrub.pending"

    def run_helper(self, helper, *args, **environment):
        env = {k: v for k, v in os.environ.items() if k not in ("SERVICE_RESULT", "EXIT_CODE", "EXIT_STATUS")}
        env.update(environment)
        return subprocess.run(["bash", str(helper), *map(str, args)], env=env, capture_output=True, text=True)

    def check_power(self, status):
        probe = self.root / "power-probe"
        probe.write_text(f"#!/bin/sh\nexit {status}\n")
        probe.chmod(0o700)
        return self.run_helper(ARGS.maintenance, "check", self.marker, probe)

    def finish(self, **env):
        result = self.run_helper(ARGS.maintenance, "finish", self.marker, **env)
        self.assertEqual(result.returncode, 0, result.stderr)

    def test_battery_skip_survives_until_successful_ac_retry(self):
        self.assertEqual(self.check_power(1).returncode, 1)
        self.assertTrue(self.marker.exists())
        self.finish(SERVICE_RESULT="exec-condition")
        self.assertTrue(self.marker.exists())
        self.assertEqual(self.check_power(0).returncode, 0)
        self.assertTrue(self.marker.exists())  # Work is still running.
        self.finish(SERVICE_RESULT="success", EXIT_CODE="exited", EXIT_STATUS="0")
        self.assertFalse(self.marker.exists())

    def test_direct_ac_run_is_also_pending_until_completion(self):
        self.assertEqual(self.check_power(0).returncode, 0)
        self.assertTrue(self.marker.exists())
        self.finish()  # Missing process result is not proof of success.
        self.assertTrue(self.marker.exists())

    def test_failure_timeout_and_interrupted_scrub_remain_pending(self):
        for result, code, status in [("exit-code", "exited", "1"), ("timeout", "killed", "TERM"), ("success", "killed", "TERM")]:
            with self.subTest(result=result, code=code):
                self.marker.touch()
                self.finish(SERVICE_RESULT=result, EXIT_CODE=code, EXIT_STATUS=status)
                self.assertTrue(self.marker.exists())

    def test_unknown_power_state_fails_closed(self):
        self.assertEqual(self.check_power(2).returncode, 255)
        self.assertTrue(self.marker.exists())

    def test_missing_state_directory_does_not_run_job(self):
        self.marker = self.root / "missing" / "scrub.pending"
        self.assertEqual(self.check_power(0).returncode, 255)

    def battery(self, name="BAT1", kind="Battery"):
        path = self.root / name
        path.mkdir()
        (path / "type").write_text(kind + "\n")
        threshold = path / "charge_control_end_threshold"
        threshold.write_text("100\n")
        return threshold

    def test_charge_limit_and_full_charge_reset(self):
        threshold = self.battery()
        other = self.battery("BAT-dock", "Mains")
        for limit in (80, 100):
            result = self.run_helper(ARGS.charge, self.root, limit)
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertEqual(threshold.read_text(), f"{limit}\n")
            self.assertEqual(other.read_text(), "100\n")

    def test_invalid_charge_limit_preserves_existing_threshold(self):
        threshold = self.battery()
        for limit in (0, 101, -1, "bad"):
            with self.subTest(limit=limit):
                result = self.run_helper(ARGS.charge, self.root, limit)
                self.assertEqual(result.returncode, 2)
                self.assertEqual(threshold.read_text(), "100\n")

    def test_unsupported_charge_control_reports_failure(self):
        result = self.run_helper(ARGS.charge, self.root, 80)
        self.assertEqual(result.returncode, 1)
        self.assertIn("No supported BAT* charge-control interface", result.stderr)


if __name__ == "__main__":
    unittest.main(argv=[__file__, *TEST_ARGS])
