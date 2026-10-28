"""Add a raw QEMU serial log without competing with the test driver's reader."""

import os
from pathlib import Path
import sys


def logged_command(command, log_path):
    """Replace the driver's single stdio serial backend, keeping its input/output."""
    serial_options = [index for index, arg in enumerate(command) if arg == "-serial"]
    if (
        len(serial_options) != 1
        or serial_options[0] + 1 >= len(command)
        or command[serial_options[0] + 1] != "stdio"
    ):
        raise ValueError("Expected exactly one test-driver -serial stdio option.")
    index = serial_options[0]
    # QEMU separates chardev fields with commas; a literal comma is doubled.
    path = str(log_path).replace(",", ",,")
    return [
        *command[:index],
        "-chardev",
        f"stdio,id=installer-serial,logfile={path},logappend=off",
        "-serial",
        "chardev:installer-serial",
        *command[index + 2 :],
    ]


def console_has_text(log_path, text):
    """Match bytes already emitted, including a prompt with no terminating newline."""
    try:
        output = Path(log_path).read_bytes()
    except FileNotFoundError:
        return False
    return text.encode() in output.replace(b"\r", b"")


def main():
    if len(sys.argv) < 3:
        raise SystemExit("Usage: serial_console.py LOGFILE QEMU [QEMU_OPTIONS ...]")
    command = logged_command(sys.argv[2:], sys.argv[1])
    os.execv(command[0], command)


if __name__ == "__main__":
    main()
