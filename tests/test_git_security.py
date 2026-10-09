"""Exercise the staged scanner and optionally the exact packaged global hook."""
import argparse
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import unittest

parser = argparse.ArgumentParser()
parser.add_argument("--scanner", type=Path, required=True)
parser.add_argument("--hook", type=Path)
args = parser.parse_args()
SCANNER = args.scanner.resolve()
HOOK = args.hook.resolve() if args.hook else None
# Synthetic fixtures are assembled to avoid embedding secret-shaped literals.
SSN = "12" + "3-45-6789"
TOKEN = "ghp_" + "A1b2C3d4E5f6G7h8I9j0K1l2M3n4O5p6Q7r8"


class SecurityTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.env = os.environ.copy()
        # Prevent the caller's Git identity, hooks, index or worktree overrides.
        for key in list(self.env):
            if key.startswith("GIT_"):
                del self.env[key]
        self.env.update(GIT_CONFIG_NOSYSTEM="1", GIT_CONFIG_GLOBAL=os.devnull)
        self.git("init", "-q")
        self.git("config", "user.name", "Test")
        self.git("config", "user.email", "test@example.invalid")
        self.git("-c", "core.hooksPath=/dev/null", "commit", "--allow-empty", "-qm", "base")

    def run_cmd(self, *cmd):
        return subprocess.run(cmd, cwd=self.root, env=self.env, text=True,
                              stdout=subprocess.PIPE, stderr=subprocess.PIPE)

    def git(self, *cmd):
        result = self.run_cmd("git", *cmd)
        self.assertEqual(result.returncode, 0, result.stderr)
        return result

    def stage(self, name, content):
        (self.root / name).write_text(content)
        self.git("add", "--", name)

    def scan(self):
        return self.run_cmd(sys.executable, str(SCANNER))

    def test_staged_pii_unusual_filename_and_redaction(self):
        self.stage("-odd name\nwith newline.txt", SSN + "\n")
        result = self.scan()
        self.assertEqual(result.returncode, 1)
        self.assertNotIn(SSN, result.stdout + result.stderr)
        self.assertIn("BLOCK:", result.stderr)

    def test_unstaged_change_cannot_hide_staged_pii(self):
        self.stage("data.txt", SSN + "\n")
        (self.root / "data.txt").write_text("redacted\n")
        self.assertEqual(self.scan().returncode, 1)

    def test_unstaged_pii_is_not_scanned(self):
        self.stage("data.txt", "safe\n")
        (self.root / "data.txt").write_text(SSN + "\n")
        self.assertEqual(self.scan().returncode, 0)

    def test_reviewed_exception_and_example_email(self):
        self.stage("example.txt", SSN + " # pii-allow\nuser@example.invalid\n")
        result = self.scan()
        self.assertEqual(result.returncode, 0)
        self.assertEqual(result.stderr, "")

    def test_git_failure_is_closed(self):
        # A non-repository invocation must error, not report a clean scan.
        result = subprocess.run([sys.executable, str(SCANNER)], cwd=self.root.parent,
                                env=self.env, capture_output=True, text=True)
        self.assertEqual(result.returncode, 2)

    def test_decimal_coefficients_are_not_card_numbers(self):
        card = "4" + "1" * 15
        self.stage("preset.json", '{"frequency": 474.7170715332031, '
                   '"gain": -17.599999999999998, "fraction": 0.' + card +
                   ', "integer": ' + card + '.25}\n')
        result = self.scan()
        self.assertEqual(result.returncode, 0, result.stderr)

    def test_card_formats_and_sentence_punctuation_still_block(self):
        card = "4" + "1" * 15
        groups = [card[i:i + 4] for i in range(0, len(card), 4)]
        for candidate in (card, " ".join(groups), "-".join(groups), card + "."):
            with self.subTest(candidate_format=len(candidate)):
                self.stage("data.txt", "Card: " + candidate + "\n")
                result = self.scan()
                self.assertEqual(result.returncode, 1)
                self.assertIn("payment-card", result.stderr)
                self.assertNotIn(candidate, result.stdout + result.stderr)

    def install_hook(self):
        if HOOK is None:
            self.skipTest("pass --hook to exercise the Nix-packaged production hook")
        hookdir = self.root / "global-hooks"
        hookdir.mkdir()
        (hookdir / "pre-commit").symlink_to(HOOK)
        self.git("config", "core.hooksPath", str(hookdir))

    def test_commit_blocks_credentials(self):
        self.install_hook()
        self.stage("credentials.txt", "github_token=" + TOKEN + "\n")
        result = self.run_cmd("git", "commit", "-qm", "must fail")
        self.assertNotEqual(result.returncode, 0)
        self.assertNotIn(TOKEN, result.stdout + result.stderr)
        self.assertEqual(self.git("rev-list", "--count", "HEAD").stdout.strip(), "1")

    def test_commit_blocks_pii(self):
        self.install_hook()
        self.stage("data.txt", SSN + "\n")
        self.assertNotEqual(self.run_cmd("git", "commit", "-qm", "must fail").returncode, 0)

    def test_local_hook_failure_is_preserved(self):
        self.install_hook()
        local = self.root / ".git/hooks/pre-commit"
        # Nix's Linux build sandbox has no /usr/bin/env. Use its supplied Bash.
        bash = shutil.which("bash", path=self.env.get("PATH"))
        self.assertIsNotNone(bash)
        local.write_text(f"#!{bash}\necho chained-hook >&2\nexit 1\n")
        local.chmod(0o755)
        self.stage("safe.txt", "safe\n")
        result = self.run_cmd("git", "commit", "-qm", "must fail")
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("chained-hook", result.stderr)

    def test_safe_commit_and_explicit_pii_opt_out(self):
        self.install_hook()
        self.stage("safe.txt", "safe\n")
        self.git("commit", "-qm", "safe commit")
        self.git("config", "hooks.piiCheck", "false")
        self.stage("data.txt", SSN + "\n")
        self.git("commit", "-qm", "explicit local exception")


unittest.main(argv=[sys.argv[0]], verbosity=2)
