"""Resolve the install-time timezone once; never locate from Nix evaluation."""

import argparse
import os
from pathlib import Path
import re
import sys
import tempfile
import urllib.error
import urllib.request
from zoneinfo import available_timezones


ENDPOINT = "https://ipapi.co/timezone/"
ASSIGNMENT = re.compile(
    r'^([ \t]*timeZone[ \t]*=[ \t]*)(null|"[A-Za-z0-9_+/\-]+")([ \t]*;)',
    re.MULTILINE,
)


def validate(zone):
    if zone not in available_timezones():
        raise ValueError("No valid IANA timezone found; use --timezone Area/City.")
    return zone


def detect():
    request = urllib.request.Request(ENDPOINT, headers={"User-Agent": "nix-framework-installer"})
    with urllib.request.urlopen(request, timeout=15) as response:
        return validate(response.read(256).decode("ascii").strip())


def configure(path, manual=None):
    text = path.read_text()
    matches = list(ASSIGNMENT.finditer(text))
    if len(matches) != 1:
        raise ValueError('Expected one timeZone = null; or timeZone = "Area/City"; assignment.')
    assignment = matches[0]
    current = assignment.group(2)
    if manual is None and current != "null":
        zone = validate(current[1:-1])
        print(f"Keeping configured timezone: {zone}")
        return zone
    if manual is None:
        print("Detecting timezone once via ipapi.co (uses your public IP).")
    zone = validate(manual) if manual is not None else detect()
    # Validation precedes any write. Only the timezone value is replaced;
    # account settings, comments, file permissions and all other text survive.
    start, end = assignment.span(2)
    replace_file(path, text[:start] + f'"{zone}"' + text[end:])
    print(f"Saved timezone: {zone} in {path}. Review this value before installation.")
    return zone


def replace_file(path, text):
    """Write a sibling temporary file and rename it over the original.

    An interruption, a full disk or a failed write leaves the reviewed
    settings file untouched instead of truncated.
    """
    mode = path.stat().st_mode & 0o7777
    fd, temporary = tempfile.mkstemp(dir=path.parent, prefix=f".{path.name}.")
    try:
        with os.fdopen(fd, "w") as handle:
            handle.write(text)
            handle.flush()
            os.fsync(handle.fileno())
        os.chmod(temporary, mode)
        os.replace(temporary, path)
    except BaseException:
        if os.path.exists(temporary):
            os.unlink(temporary)
        raise


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--settings", type=Path, default=Path("settings.nix"))
    parser.add_argument("--timezone", help="Explicit IANA zone; skips the network lookup")
    args = parser.parse_args()
    try:
        configure(args.settings, args.timezone)
    except (OSError, ValueError, UnicodeError, urllib.error.URLError) as error:
        print(f"Timezone setup failed: {error}\nRetry or use --timezone Area/City.", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
