"""Regression checks for QEMU's raw log and the installer's non-newline prompt."""

import argparse
import importlib.util
from pathlib import Path
import subprocess
import sys
import tempfile
import threading
import time
import unittest


parser = argparse.ArgumentParser()
parser.add_argument(
    "--helper",
    type=Path,
    default=Path(__file__).resolve().parent / "installer-vm/serial_console.py",
)
args, test_args = parser.parse_known_args()
spec = importlib.util.spec_from_file_location("serial_console", args.helper)
assert spec is not None and spec.loader is not None
serial_console = importlib.util.module_from_spec(spec)
spec.loader.exec_module(serial_console)


PROMPT = "Please enter passphrase for disk disk-main-cryptroot (cryptroot):"


class SerialConsole(unittest.TestCase):
    def test_keeps_the_driver_stdio_channel_and_other_arguments(self):
        command = [
            "/nix/store/qemu/bin/qemu-system-x86_64",
            "-m",
            "2048",
            "-chardev",
            "socket,id=shell,path=/tmp/shell",
            "-serial",
            "stdio",
            "-nographic",
        ]
        result = serial_console.logged_command(
            command, Path("/tmp/path with space,comma/serial.log")
        )
        self.assertEqual(result[:5], command[:5])
        self.assertEqual(
            result[5:],
            [
                "-chardev",
                "stdio,id=installer-serial,logfile=/tmp/path with space,,comma/serial.log,logappend=off",
                "-serial",
                "chardev:installer-serial",
                "-nographic",
            ],
        )
        self.assertEqual(result.count("-serial"), 1)
        self.assertEqual(command[6], "stdio")  # The caller's arguments are preserved.

    def test_refuses_an_unexpected_driver_serial_configuration(self):
        for command in (
            ["qemu"],
            ["qemu", "-serial"],
            ["qemu", "-serial", "file:log"],
            ["qemu", "-serial", "stdio", "-serial", "stdio"],
        ):
            with (
                self.subTest(command=command),
                self.assertRaisesRegex(ValueError, "exactly one"),
            ):
                serial_console.logged_command(command, "/tmp/serial.log")

    def test_handles_missing_partial_and_undecodable_output(self):
        with tempfile.TemporaryDirectory() as temporary:
            log = Path(temporary) / "serial.log"
            self.assertFalse(serial_console.console_has_text(log, PROMPT))
            log.write_bytes(b"\xffBoot\r\n" + PROMPT[:30].encode())
            self.assertFalse(serial_console.console_has_text(log, PROMPT))
            with log.open("ab", buffering=0) as output:
                output.write(PROMPT[30:].encode())
            self.assertTrue(serial_console.console_has_text(log, PROMPT))

    def test_detects_fragmented_prompt_before_newline_or_process_exit(self):
        with tempfile.TemporaryDirectory() as temporary:
            log = Path(temporary) / "serial.log"
            # Model QEMU's unbuffered chardev logfile alongside the driver's
            # newline-buffered stdout stream. The guest waits for input.
            emitter = """
import os, sys
with open(sys.argv[1], 'wb', buffering=0) as log:
    for chunk in (b'Booting\\r\\n', sys.argv[2][:30].encode(), sys.argv[2][30:].encode()):
        log.write(chunk)
        os.write(sys.stdout.fileno(), chunk)
    assert sys.stdin.buffer.readline() == b'fixture-passphrase\\n'
    os.write(sys.stdout.fileno(), b'\\nUnlocked\\n')
"""
            process = subprocess.Popen(
                [sys.executable, "-c", emitter, str(log), PROMPT],
                stdin=subprocess.PIPE,
                stdout=subprocess.PIPE,
            )
            complete_lines = []

            def read_lines():
                for line in process.stdout:
                    complete_lines.append(line)

            reader = threading.Thread(target=read_lines, daemon=True)
            reader.start()
            try:
                deadline = time.monotonic() + 5
                while not serial_console.console_has_text(log, PROMPT):
                    self.assertIsNone(
                        process.poll(), "Emitter exited before receiving the passphrase"
                    )
                    self.assertLess(
                        time.monotonic(),
                        deadline,
                        "Unterminated prompt was not detected",
                    )
                    time.sleep(0.01)
                self.assertIsNone(
                    process.poll(),
                    "Prompt must be recognized while the process is alive",
                )
                self.assertNotIn(PROMPT.encode(), b"".join(complete_lines))
                process.stdin.write(b"fixture-passphrase\n")
                process.stdin.flush()
                self.assertEqual(process.wait(timeout=5), 0)
                reader.join(timeout=5)
                self.assertFalse(reader.is_alive())
                self.assertIn(b"Unlocked", b"".join(complete_lines))
            finally:
                if process.poll() is None:
                    process.kill()
                    process.wait(timeout=5)
                reader.join(timeout=5)
                process.stdin.close()
                process.stdout.close()


if __name__ == "__main__":
    unittest.main(argv=[sys.argv[0], *test_args], verbosity=2)
