# Git commit safety

Home Manager installs common Git review settings and a global pre-commit hook.
The hook checks only added, staged content; it does not upload source files or
send findings to a service.

Client-side hooks reduce accidental disclosure. They are not an enforcement
boundary: Git supports `--no-verify`, repository-local configuration can
override the global hook path, and another machine may not have these checks.
Shared repositories should also run a secret scanner in protected CI before
deployment or release.

## Checks performed before each commit

The hook runs these stages in order:

1. Gitleaks scans the staged Git diff with its maintained credential and secret
   rules. Finding output is redacted.
2. The local PII scanner blocks these high-confidence values:
   - valid-looking US Social Security numbers;
   - payment-card candidates that pass the Luhn checksum;
   - IBAN candidates that pass the MOD-97 checksum.
3. The PII scanner prints non-blocking review warnings for:
   - non-example email addresses;
   - labeled telephone numbers;
   - labeled dates of birth;
   - precise coordinates with a location label.
4. If an executable conventional `.git/hooks/pre-commit` already exists, the
   global hook runs it after the security checks.

Only newly added staged lines are checked for PII, so an unrelated edit does
not become blocked by an old value elsewhere in the file. Gitleaks is also run
in staged/pre-commit mode rather than rescanning the complete history.

The PII categories are deliberately conservative. Treating arbitrary names,
addresses, or phone-like number sequences as hard failures creates too many
false positives in tests, schemas, and documentation. Warnings still identify
the exact file and line for review without printing the possible PII itself.

These checks are not a data-loss-prevention system. Binary files, encrypted or
compressed payloads, unusual encodings, unsupported identifiers, and secrets
outside the maintained Gitleaks rules may not be detected. Staging also writes
a blob into the local Git object database before the hook runs; the hook stops
the commit, but it does not erase that local object.

## Common Git settings

`home/modules/git.nix` also enables:

- verbose commit editing so the staged patch is visible below the message;
- automatic pruning of deleted remote-tracking branches on fetch;
- histogram diffs and moved-line coloring;
- `zdiff3` conflict markers with the common ancestor included;
- `simple` push behavior and automatic upstream setup;
- trailing-space and space-before-tab diagnostics;
- `main` as the initial branch name.

`rerere` is intentionally not enabled globally. Its recorded conflict
resolutions can retain content that was later removed, including accidentally
staged secrets.

## Verify after installation

Confirm that the scanners and global hook are present:

```bash
command -v gitleaks
command -v git-staged-pii-scan
git-staged-pii-scan --self-test
git config --global --show-origin --get core.hooksPath
git config --global --get hooks.gitleaks
git config --global --get hooks.piiCheck
```

Inside a repository, scan currently staged changes without committing:

```bash
gitleaks git --pre-commit --redact --staged --verbose
git-staged-pii-scan
```

For a deliberate full-history credential audit:

```bash
gitleaks git --redact --verbose .
```

## Resolve findings safely

For a real credential or PII finding:

1. Remove it from the staged content.
2. Revoke or rotate any credential that has left the machine.
3. Store its replacement in a password manager, an encrypted `sops`/`age`
   file, or the deployment platform's secret store.
4. Stage the corrected file and run both scanners again.

For a confirmed Gitleaks false positive, add the narrowest possible finding
fingerprint to the repository's `.gitleaksignore`. For a confirmed PII false
positive, add `pii-allow` to the same line in an appropriate comment. Review
either exception before committing it.

Git's emergency bypass skips every pre-commit hook, including any
repository-local hook chained by this configuration:

```bash
git commit --no-verify
```

Prefer a narrow per-repository override when one scanner is unsuitable for a
specific repository:

```bash
git config hooks.gitleaks false
git config hooks.piiCheck false
```

Remove an override to inherit the protected global default again:

```bash
git config --unset hooks.gitleaks
git config --unset hooks.piiCheck
```

The PII scanner fails closed if one file's staged text diff exceeds 20 MiB.
Split the commit, or disable only `hooks.piiCheck` after reviewing that diff by
another method.

## Repository hook compatibility

Git uses one effective `core.hooksPath`. Home Manager points the global value at
the managed security hook, which then chains an executable conventional
`.git/hooks/pre-commit` when present.

A repository that sets its own `core.hooksPath` overrides the global path, so
the managed scanner will not run there. Check the effective source with:

```bash
git config --show-origin --get core.hooksPath
```

For such a repository, add the equivalent Gitleaks and PII commands to its
managed hook framework and CI workflow.

## Primary references

- [Gitleaks](https://github.com/gitleaks/gitleaks)
- [Gitleaks pre-commit hook definition](https://github.com/gitleaks/gitleaks/blob/master/.pre-commit-hooks.yaml)
- [Git hooks](https://git-scm.com/docs/githooks)
- [Git configuration](https://git-scm.com/docs/git-config)
