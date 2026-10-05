"""Check installer detection, manual selection and failure safety without geolocation."""

import argparse
import importlib.util
import io
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch
import urllib.error

parser = argparse.ArgumentParser()
parser.add_argument("--helper", type=Path, default=Path(__file__).resolve().parents[1] / "scripts/detect-timezone.py")
args, test_args = parser.parse_known_args()
spec = importlib.util.spec_from_file_location("timezone_helper", args.helper)
helper = importlib.util.module_from_spec(spec)
spec.loader.exec_module(helper)


class InstallTimezone(unittest.TestCase):
    def setUp(self):
        temp = tempfile.TemporaryDirectory()
        self.addCleanup(temp.cleanup)
        self.path = Path(temp.name) / "settings.nix"
        self.original = '{\n  timeZone = null; # detect once\n  user.name = "example";\n}\n'
        self.path.write_text(self.original)
        self.path.chmod(0o600)
        self.output = patch('sys.stdout', new_callable=io.StringIO)
        self.output.start()
        self.addCleanup(self.output.stop)

    def test_detect_persist_then_skip_network(self):
        with patch.object(helper.urllib.request, 'urlopen', return_value=io.BytesIO(b'Europe/Paris\n')) as lookup:
            helper.configure(self.path)
            helper.configure(self.path)
            lookup.assert_called_once()
            self.assertEqual(lookup.call_args.kwargs['timeout'], 15)
            self.assertEqual(lookup.call_args.args[0].full_url, 'https://ipapi.co/timezone/')
        self.assertEqual(self.path.read_text(), self.original.replace('null', '"Europe/Paris"'))
        self.assertEqual(self.path.stat().st_mode & 0o777, 0o600)

    def test_manual_utc_and_override_skip_network(self):
        with patch.object(helper.urllib.request, 'urlopen') as lookup:
            helper.configure(self.path, 'UTC')
            helper.configure(self.path, 'America/Chicago')
            lookup.assert_not_called()
        self.assertIn('timeZone = "America/Chicago";', self.path.read_text())

    def test_preserve_explicit_zone(self):
        text = self.original.replace('null', '"Asia/Tokyo"')
        self.path.write_text(text)
        with patch.object(helper.urllib.request, 'urlopen') as lookup:
            helper.configure(self.path)
            lookup.assert_not_called()
        self.assertEqual(self.path.read_text(), text)

    def test_invalid_responses_do_not_write(self):
        for body in (b'', b'None', b'{"error":true}', b'../../etc/passwd', b'"; bad = true;', b'Not/AZone', b'\xff'):
            with self.subTest(body=body), patch.object(helper.urllib.request, 'urlopen', return_value=io.BytesIO(body)):
                with self.assertRaises((ValueError, UnicodeError)):
                    helper.configure(self.path)
                self.assertEqual(self.path.read_text(), self.original)

    def test_lookup_failure_does_not_write(self):
        for error in (TimeoutError(), urllib.error.HTTPError(helper.ENDPOINT, 429, 'Rate limited', {}, None)):
            with self.subTest(error=error), patch.object(helper.urllib.request, 'urlopen', side_effect=error):
                with self.assertRaises(OSError):
                    helper.configure(self.path)
                self.assertEqual(self.path.read_text(), self.original)

    def test_invalid_manual_zone_does_not_write_or_query(self):
        with patch.object(helper.urllib.request, 'urlopen') as lookup:
            with self.assertRaises(ValueError):
                helper.configure(self.path, 'Wrong/Zone')
            lookup.assert_not_called()
        self.assertEqual(self.path.read_text(), self.original)

    def test_interrupted_write_leaves_settings_intact(self):
        real_open = io.open

        class FailingWriter:
            def __init__(self, inner):
                self.inner = inner

            def write(self, data):
                raise OSError('simulated interruption while writing')

            def __enter__(self):
                return self

            def __exit__(self, *exc):
                return self.inner.__exit__(*exc)

            def __getattr__(self, name):
                return getattr(self.inner, name)

        def failing_open(file, mode='r', *args, **kwargs):
            handle = real_open(file, mode, *args, **kwargs)
            return FailingWriter(handle) if 'w' in mode else handle

        with patch('io.open', failing_open):
            with self.assertRaises(OSError):
                helper.configure(self.path, 'UTC')
        self.assertEqual(self.path.read_text(), self.original)
        self.assertEqual(self.path.stat().st_mode & 0o777, 0o600)
        self.assertEqual([entry.name for entry in self.path.parent.iterdir()], ['settings.nix'])

    def test_ambiguous_or_missing_assignment_is_untouched(self):
        for text in ('{}\n', self.original + 'timeZone = null;\n'):
            self.path.write_text(text)
            with patch.object(helper.urllib.request, 'urlopen') as lookup:
                with self.assertRaises(ValueError):
                    helper.configure(self.path)
                lookup.assert_not_called()
            self.assertEqual(self.path.read_text(), text)


if __name__ == '__main__':
    unittest.main(argv=[__file__, *test_args])
