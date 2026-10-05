#!/usr/bin/env python3
"""Inspect only added, staged lines for common high-confidence PII."""

from __future__ import annotations

import os
import re
import subprocess
import sys
from dataclasses import dataclass


ALLOW_MARKER = "pii-allow"
MAX_DIFF_BYTES = 20 * 1024 * 1024

HUNK_RE = re.compile(rb"^@@ -\d+(?:,\d+)? \+(\d+)(?:,\d+)? @@")
SSN_RE = re.compile(
    r"(?<!\d)(?!000|666|9\d{2})(\d{3})[- ](?!00)(\d{2})[- ](?!0000)(\d{4})(?!\d)"
)
# Do not interpret a decimal's integer/fractional digits as a standalone card.
# A sentence-ending period remains valid punctuation around a card candidate.
CARD_RE = re.compile(r"(?<![A-Za-z0-9])(?<!\d\.)(?:\d[ -]?){12,18}\d(?![A-Za-z0-9])(?!\.\d)")
IBAN_RE = re.compile(r"\b[A-Z]{2}\d{2}(?:[ ]?[A-Z0-9]){11,30}\b", re.IGNORECASE)
EMAIL_RE = re.compile(r"\b[A-Z0-9._%+-]+@([A-Z0-9.-]+\.[A-Z]{2,})\b", re.IGNORECASE)
PHONE_RE = re.compile(
    r"\b(?:phone|mobile|telephone|tel)\b[^:=\n]{0,20}[:=]\s*[\"']?\+?[0-9][0-9 .()/-]{6,}[0-9]",
    re.IGNORECASE,
)
DOB_RE = re.compile(
    r"\b(?:date\s+of\s+birth|birth\s*date|dob)\b[^:=\n]{0,12}[:=]\s*[\"']?"
    r"(?:19|20)\d{2}[-/](?:0[1-9]|1[0-2])[-/](?:0[1-9]|[12]\d|3[01])",
    re.IGNORECASE,
)
LOCATION_RE = re.compile(
    r"\b(?:latitude|longitude|gps)\b[^:=\n]{0,12}[:=]\s*-?\d{1,3}\.\d{4,}",
    re.IGNORECASE,
)

SAFE_EMAIL_DOMAINS = {
    "example.com",
    "example.net",
    "example.org",
    "example.invalid",
    "users.noreply.github.com",
}


@dataclass(frozen=True)
class Finding:
    path: str
    line: int
    category: str
    blocking: bool


def run_git(*args: str) -> bytes:
    result = subprocess.run(
        ["git", *args],
        check=False,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
    )
    if result.returncode != 0:
        message = result.stderr.decode("utf-8", "replace").strip()
        raise RuntimeError(message or f"git {' '.join(args)} failed")
    return result.stdout


def luhn_valid(value: str) -> bool:
    digits = [int(character) for character in value if character.isdigit()]
    if not 13 <= len(digits) <= 19 or len(set(digits)) == 1:
        return False

    total = 0
    parity = len(digits) % 2
    for index, digit in enumerate(digits):
        if index % 2 == parity:
            digit *= 2
            if digit > 9:
                digit -= 9
        total += digit
    return total % 10 == 0


def iban_valid(value: str) -> bool:
    compact = "".join(value.split()).upper()
    if not 15 <= len(compact) <= 34 or not compact[:2].isalpha():
        return False

    rearranged = compact[4:] + compact[:4]
    remainder = 0
    for character in rearranged:
        fragment = character if character.isdigit() else str(ord(character) - 55)
        for digit in fragment:
            remainder = (remainder * 10 + int(digit)) % 97
    return remainder == 1


def analyze_line(path: str, line_number: int, line: str) -> list[Finding]:
    if ALLOW_MARKER in line.lower():
        return []

    findings: list[Finding] = []

    if SSN_RE.search(line):
        findings.append(Finding(path, line_number, "valid-looking US SSN", True))

    if any(luhn_valid(match.group(0)) for match in CARD_RE.finditer(line)):
        findings.append(Finding(path, line_number, "Luhn-valid payment-card number", True))

    if any(iban_valid(match.group(0)) for match in IBAN_RE.finditer(line)):
        findings.append(Finding(path, line_number, "checksum-valid IBAN", True))

    for match in EMAIL_RE.finditer(line):
        domain = match.group(1).lower()
        if domain not in SAFE_EMAIL_DOMAINS and not domain.endswith(".invalid"):
            findings.append(Finding(path, line_number, "email address", False))
            break

    warning_patterns = (
        (PHONE_RE, "labeled phone number"),
        (DOB_RE, "labeled date of birth"),
        (LOCATION_RE, "precise labeled location"),
    )
    for pattern, category in warning_patterns:
        if pattern.search(line):
            findings.append(Finding(path, line_number, category, False))

    return findings


def staged_paths() -> list[str]:
    raw_paths = run_git("diff", "--cached", "--name-only", "--diff-filter=ACMR", "-z")
    return [os.fsdecode(path) for path in raw_paths.split(b"\0") if path]


def added_lines(path: str) -> list[tuple[int, str]]:
    patch = run_git(
        "diff",
        "--cached",
        "--no-color",
        "--no-ext-diff",
        "--no-renames",
        "--unified=0",
        "--diff-filter=ACMR",
        "--",
        path,
    )
    if len(patch) > MAX_DIFF_BYTES:
        raise RuntimeError(
            f"staged diff for {path!r} exceeds the "
            f"{MAX_DIFF_BYTES // (1024 * 1024)} MiB PII scan limit"
        )

    additions: list[tuple[int, str]] = []
    new_line: int | None = None
    for raw_line in patch.splitlines():
        hunk = HUNK_RE.match(raw_line)
        if hunk:
            new_line = int(hunk.group(1))
            continue
        if new_line is None:
            continue
        if raw_line.startswith(b"+"):
            additions.append((new_line, raw_line[1:].decode("utf-8", "replace")))
            new_line += 1
        elif raw_line.startswith(b" "):
            new_line += 1
        elif raw_line.startswith(b"diff --git "):
            new_line = None

    return additions


def self_test() -> None:
    card = "4" + ("1" * 15)
    iban = "".join(("GB82", "WEST", "1234", "5698", "7654", "32"))
    ssn = "".join(("12", "3-45", "-6789"))
    assert luhn_valid(card)
    assert not luhn_valid(card[:-1] + "2")
    assert iban_valid(iban)
    assert not iban_valid(iban[:-1] + "3")
    assert SSN_RE.search(ssn)
    assert not SSN_RE.search("000-12-3456")


def main() -> int:
    if sys.argv[1:] == ["--self-test"]:
        self_test()
        print("staged PII scanner self-test passed")
        return 0

    try:
        paths = staged_paths()
        findings = [
            finding
            for path in paths
            for line_number, line in added_lines(path)
            for finding in analyze_line(path, line_number, line)
        ]
    except RuntimeError as error:
        print(f"PII scan failed: {error}", file=sys.stderr)
        return 2

    blocking = [finding for finding in findings if finding.blocking]
    warnings = [finding for finding in findings if not finding.blocking]

    for finding in blocking:
        print(
            f"BLOCK: {finding.category} at {finding.path!r}:{finding.line}",
            file=sys.stderr,
        )
    for finding in warnings:
        print(
            f"REVIEW: possible {finding.category} at {finding.path!r}:{finding.line}",
            file=sys.stderr,
        )

    if blocking:
        print(
            "Commit stopped. Remove/redact the value, or add 'pii-allow' to "
            "that reviewed false-positive line.",
            file=sys.stderr,
        )
        return 1

    if warnings:
        print("Review the possible PII warnings above before pushing.", file=sys.stderr)

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
