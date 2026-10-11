"""Verify sensor units and honest unavailable readings without touching hardware."""
import argparse
import importlib.util
from pathlib import Path
import sys
import tempfile
import unittest

parser = argparse.ArgumentParser()
parser.add_argument('--script', type=Path, default=Path(__file__).resolve().parents[1] / 'scripts/power-report.py')
args, rest = parser.parse_known_args()
spec = importlib.util.spec_from_file_location('report', args.script)
report = importlib.util.module_from_spec(spec)
spec.loader.exec_module(report)


class Report(unittest.TestCase):
    def setUp(self):
        temporary = tempfile.TemporaryDirectory()
        self.addCleanup(temporary.cleanup)
        self.root = Path(temporary.name)

    def supply(self, name='BAT0', **values):
        path = self.root / 'class/power_supply' / name
        path.mkdir(parents=True, exist_ok=True)
        for key, value in values.items():
            (path / key).write_text(str(value))
        return path

    def test_power_and_energy_units(self):
        self.supply(type='Battery', status='Discharging', power_now=6500000, energy_now=45000000)
        data = report.snapshot(self.root)
        self.assertEqual(data['total_battery_discharge_w'], 6.5)
        self.assertEqual(data['batteries'][0]['energy_wh'], 45)

    def test_current_voltage_fallback_is_labeled_estimate(self):
        path = self.supply(type='Battery', status='Discharging', current_now=-500000, voltage_now=13000000)
        data = report.battery(path)
        self.assertEqual(data['discharge_w'], 6.5)
        self.assertIn('estimate', data['power_source'])
        self.assertIsNone(data['energy_wh'])

    def test_absent_and_peripheral_batteries_are_excluded(self):
        self.supply(type='Battery', status='Discharging', power_now=6000000)
        self.supply('mouse', type='Battery', scope='Device', status='Discharging', power_now=1000000)
        self.supply('BAT1', type='Battery', present=0)
        self.assertEqual(report.snapshot(self.root)['total_battery_discharge_w'], 6)

    def test_unknown_or_charging_never_looks_like_zero_consumption(self):
        self.assertIsNone(report.snapshot(self.root)['total_battery_discharge_w'])
        for status in ('Charging', 'Full', 'Unknown', 'Discharging'):
            with self.subTest(status=status):
                path = self.supply(type='Battery', status=status, power_now='invalid')
                self.assertIsNone(report.battery(path)['discharge_w'])
        self.supply(type='Battery', status='Charging', power_now=7000000)
        self.assertIsNone(report.snapshot(self.root)['total_battery_discharge_w'])

    def test_multiple_batteries_require_all_readings(self):
        self.supply(type='Battery', status='Discharging', power_now=6000000)
        self.supply('BAT1', type='Battery', status='Discharging')
        self.assertIsNone(report.snapshot(self.root)['total_battery_discharge_w'])
        self.supply('BAT1', power_now=1000000)
        self.assertEqual(report.snapshot(self.root)['total_battery_discharge_w'], 7)

    def test_commands_report_missing_tool_and_permission_failures(self):
        self.assertIsNone(report.command(['/nonexistent/framework-tool'])['returncode'])
        data = report.command([sys.executable, '-c', 'import sys; print("Permission denied", file=sys.stderr); sys.exit(1)'])
        self.assertEqual(data['returncode'], 1)
        self.assertIn('Permission denied', data['error'])


if __name__ == '__main__':
    unittest.main(argv=[sys.argv[0], *rest])
