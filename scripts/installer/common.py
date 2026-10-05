"""Shared installer process and configuration boundaries."""

from dataclasses import dataclass, replace
import json
import os
from pathlib import Path
import re
import subprocess
import sys


class Stop(RuntimeError):
    pass


def run(*args, capture=False, cwd=None):
    result = subprocess.run(args, cwd=cwd, check=True, text=True,
                            stdout=subprocess.PIPE if capture else None)
    return result.stdout.strip() if capture else None


def query(*args, cwd=None):
    return json.loads(run(*args, capture=True, cwd=cwd))


@dataclass(frozen=True)
class Config:
    source: Path
    hostname: str
    username: str
    disk: str
    declarative_password: bool = False
    source_tree: str = ''
    base_commit: str = ''

    @property
    def flake(self):
        return f"{self.source}#{self.hostname}"


def read_config(source):
    data = query('nix', 'eval', '--json', '--file', str(source / 'settings.nix'),
                 '--apply', '''s: { inherit (s) hostname diskDevice timeZone;
                   username = s.user.name; secureBoot = s.features.secureBoot;
                   declarativePassword = s.user.hashedPassword != null || s.user.initialPassword != null; }''')
    if not re.fullmatch(r'[a-zA-Z0-9][a-zA-Z0-9-]{0,62}', data['hostname']):
        raise Stop('Invalid hostname.')
    if not re.fullmatch(r'[a-z_][a-z0-9_-]{0,31}', data['username']) or data['username'] == 'root':
        raise Stop('A valid non-root installation username is required.')
    disk = data['diskDevice']
    if (not re.fullmatch(r'/dev/disk/by-id/[A-Za-z0-9_.:+-]+', disk)
            or 'REPLACE' in disk.upper() or re.search(r'-part\d+$', disk)):
        raise Stop('Select a real whole-disk /dev/disk/by-id/ path in settings.nix.')
    if not data['timeZone']:
        raise Stop('Resolve timeZone first: nix run .#detect-timezone.')
    if data['secureBoot']:
        raise Stop('Fresh installation requires features.secureBoot = false; enroll keys after first boot.')
    return Config(source, data['hostname'], data['username'], disk, data['declarativePassword'])


def validate_source(source):
    # A self-contained source snapshot must not depend on mutable host paths.
    if source.is_symlink() or any(path.is_symlink() for path in source.rglob('*')):
        raise Stop('Source symlinks are unsupported; copy reviewed files into the checkout instead.')


def snapshot(directory):
    directory = directory.resolve(strict=True)
    # Git's tracked working tree is the source boundary. Never copy .git or
    # untracked/ignored files to the target; deliberate new config must be staged.
    top = Path(run('git', '-C', str(directory), 'rev-parse', '--show-toplevel', capture=True)).resolve()
    if top != directory:
        raise Stop('Run from the root of a reviewed Git checkout (or use --config).')
    for name in ('flake.nix', 'flake.lock', 'settings.nix'):
        run('git', '-C', str(directory), 'ls-files', '--error-unmatch', name, capture=True)
    # A reviewed index, including deliberate settings edits, is authoritative.
    try:
        run('git', '-C', str(directory), 'diff', '--quiet', '--ignore-submodules=none')
    except subprocess.CalledProcessError as error:
        raise Stop('Unstaged tracked edits remain. Review git diff, stage intended changes, and retry.') from error
    tree = run('git', '-C', str(directory), 'write-tree', capture=True)
    revision = run('git', '-C', str(directory), 'rev-parse', 'HEAD', capture=True)
    print(f'Reviewed base commit: {revision}; staged tree: {tree}', flush=True)
    # Metadata alone can report an unrealized store path with lazy fetching.
    # Archive materializes the Git-filtered root and every locked input.
    metadata = query('nix', 'flake', 'archive', '--json', '--no-update-lock-file',
                     '--no-write-lock-file', '.', cwd=directory)
    run('git', '-C', str(directory), 'diff', '--quiet', '--ignore-submodules=none')
    if run('git', '-C', str(directory), 'write-tree', capture=True) != tree:
        raise Stop('The staged configuration changed while taking its snapshot; retry after review.')
    source = Path(metadata['path'])
    if source.parent != Path('/nix/store') or not source.is_dir():
        raise Stop('Nix did not return an immutable source snapshot.')
    validate_source(source)
    print(f"Using immutable configuration: {source}", flush=True)
    return replace(read_config(source), source_tree=tree, base_commit=revision)


def evaluate(config):
    from layout import evaluate_layout

    derivation = run('nix', 'eval', '--raw', f'{config.source}#nixosConfigurations.{config.hostname}.config.system.build.toplevel.drvPath',
                     '--no-update-lock-file', '--no-write-lock-file', capture=True)
    print(f'Evaluated system: {derivation}', flush=True)
    actual = run('nix', 'eval', '--raw', f'{config.source}#nixosConfigurations.{config.hostname}.config.disko.devices.disk.main.device',
                 '--no-update-lock-file', '--no-write-lock-file', capture=True)
    if actual != config.disk:
        raise Stop('The evaluated Disko target differs from settings.diskDevice.')
    return evaluate_layout(config)


def live_environment():
    if sys.platform != 'linux' or os.geteuid() != 0:
        raise Stop('Use a root shell in the NixOS UEFI installer ISO.')
    if 'ID=nixos' not in Path('/etc/os-release').read_text().splitlines():
        raise Stop('Use the NixOS installer ISO.')
    if not Path('/sys/firmware/efi/efivars').is_dir():
        raise Stop('The installer must be booted in UEFI mode.')
    for target, expected in (('/', 'tmpfs'), ('/iso', 'iso9660')):
        fs = query('findmnt', '--json', '--mountpoint', target, '--output', 'FSTYPE')['filesystems']
        if len(fs) != 1 or fs[0]['fstype'] != expected:
            raise Stop(f'Unsupported live layout at {target}: observed {fs}, expected {expected}. Use the standard NixOS ISO; never bypass this guard on an installed system.')
