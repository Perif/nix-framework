"""Exercise the actual Git/Nix snapshot boundary without accessing any disk target."""

import argparse
from pathlib import Path
import subprocess
import sys
import tempfile


parser = argparse.ArgumentParser()
parser.add_argument('--helpers', type=Path, required=True)
parser.add_argument('--config', type=Path, required=True)
args = parser.parse_args()
sys.path.insert(0, str(args.helpers.resolve()))
import common  # noqa: E402
import layout  # noqa: E402


with tempfile.TemporaryDirectory(prefix='installer-source-test-') as temporary:
    checkout = Path(temporary) / 'config'
    subprocess.run(['git', 'clone', '--quiet', '--local', '--no-hardlinks',
                    str(args.config.resolve()), str(checkout)], check=True)
    settings = checkout / 'settings.nix'
    settings.write_text(settings.read_text().replace(
        'hostKey = "framework-pro";',
        'hostKey = "framework-pro";\n\n  diskDevice = "/dev/disk/by-id/ci-validation-disk";'
    ))
    subprocess.run(['git', '-C', str(checkout), 'add', 'settings.nix'], check=True)
    (checkout / 'untracked-canary').write_text('must not enter source snapshot')
    (checkout / 'ignored-canary').write_text('must not enter source snapshot')
    with (checkout / '.git/info/exclude').open('a') as excludes:
        excludes.write('\nignored-canary\n')
    config = common.snapshot(checkout)
    assert config.disk == '/dev/disk/by-id/ci-validation-disk'
    assert config.source.is_dir()
    evaluated = layout.evaluate_layout(config)
    assert evaluated.targets['/mnt/boot'] == ('vfat', '/')
    assert evaluated.targets['/mnt/var/lib/private/ollama'] == ('btrfs', '/ollama')
    assert evaluated.esp_partition == 1 and evaluated.crypt_partition == 2
    assert evaluated.minimum_disk_bytes > 41 * 1024**3
    assert (config.source / 'settings.nix').read_bytes() == settings.read_bytes()
    for excluded in ('.git', 'untracked-canary', 'ignored-canary'):
        assert not (config.source / excluded).exists(), excluded
    reviewed_settings = settings.read_text()
    for flag in ('assume-unchanged', 'skip-worktree'):
        subprocess.run(['git', '-C', str(checkout), 'update-index', f'--{flag}',
                        'settings.nix'], check=True)
        settings.write_text(reviewed_settings + f'\n# Hidden local edit under {flag}\n')
        assert settings.read_text() != reviewed_settings
        # Ordinary diff cannot see this unstaged change, but the installer must.
        subprocess.run(['git', '-C', str(checkout), 'diff', '--quiet'], check=True)
        try:
            common.snapshot(checkout)
        except common.Stop as error:
            assert 'flags can hide tracked edits' in str(error), str(error)
        else:
            raise AssertionError(f'{flag} must not hide worktree edits from the snapshot guard')
        settings.write_text(reviewed_settings)
        subprocess.run(['git', '-C', str(checkout), 'update-index', f'--no-{flag}',
                        'settings.nix'], check=True)
    settings.write_text(settings.read_text() + '\n# Unreviewed edit\n')
    try:
        common.snapshot(checkout)
    except common.Stop as error:
        assert 'Unstaged' in str(error), str(error)
    else:
        raise AssertionError('Unstaged tracked changes must be rejected')
    print('Real Git/Nix snapshot, staged edits, excluded files, hidden-index flags, and dirty-tree refusal passed.')
