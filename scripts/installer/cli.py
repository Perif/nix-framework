"""Independent, fail-closed installation stages for the standard NixOS UEFI ISO."""

import argparse
import fcntl
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile

from common import Stop, evaluate, live_environment, read_config, run, snapshot, validate_source
from storage import fresh_storage, show_disk, verify_mounts


def disko(config, dry=False):
    args = ['nix', 'run', f'{config.source}#disko', '--no-update-lock-file', '--no-write-lock-file', '--']
    if dry:
        args.append('--dry-run')
    run(*args, '--mode', 'destroy,format,mount', '--flake', config.flake)


def format_disk(config):
    evaluate(config)
    before = fresh_storage(config)
    show_disk(config, before)
    if not sys.stdin.isatty():
        raise Stop('Formatting requires an interactive terminal; no unattended confirmation option exists.')
    expected = f'ERASE {config.disk}'
    print(f'ALL DATA ON THIS DISK WILL BE LOST. Type exactly: {expected}', flush=True)
    if input().strip() != expected:
        raise Stop('Disk erase confirmation did not match; nothing was formatted.')
    if fresh_storage(config) != before:
        raise Stop('Disk identity changed during confirmation; nothing was formatted.')
    disko(config)
    verify_mounts(config)


def copy_source(config):
    validate_source(config.source)
    parent = Path('/mnt/etc')
    target = parent / 'nixos'
    if parent.is_symlink() or target.is_symlink():
        raise Stop('Refusing a symlink at the target configuration path.')
    parent.mkdir(exist_ok=True)
    if target.exists():
        # Never silently mix a retry with an old configuration. Use the existing
        # target only if byte-for-byte identical; manual edits need explicit recovery.
        comparison = subprocess.run(['diff', '-qr', '--no-dereference', str(config.source), str(target)],
                                    stdout=subprocess.PIPE, text=True)
        if comparison.returncode == 1:
            raise Stop('Target configuration differs; preserve/review it before retrying.')
        comparison.check_returncode()
        return target
    staging = Path(tempfile.mkdtemp(prefix='.nixos-stage-', dir=parent))
    try:
        shutil.copytree(config.source, staging, dirs_exist_ok=True, symlinks=True)
        if (staging / '.git').exists():
            raise Stop('Source snapshot unexpectedly includes Git metadata.')
        for root, dirs, files in os.walk(staging):
            Path(root).chmod(0o755)
            for name in files:
                path = Path(root) / name
                if not path.is_symlink():
                    path.chmod(0o755 if path.stat().st_mode & 0o111 else 0o644)
        staging.rename(target)
    finally:
        if staging.exists():
            shutil.rmtree(staging)
    return target


def install_system(config):
    evaluate(config)
    before = verify_mounts(config)
    target = copy_source(config)
    if read_config(target) != type(config)(target, config.hostname, config.username, config.disk, config.declarative_password):
        raise Stop('Copied configuration does not match the reviewed selection.')
    if verify_mounts(config) != before:
        raise Stop('Disk identity changed before installation.')
    run('nixos-install', '--root', '/mnt', '--flake', f'{target}#{config.hostname}', '--no-root-passwd')
    print('Installation finished. Run the account stage before rebooting.', flush=True)


def account():
    # The installed copy is authoritative, not an old variable or the live checkout.
    installed = Path('/mnt/etc/nixos')
    if installed.resolve() != installed:
        raise Stop('Installed configuration path must not contain a symlink.')
    config = read_config(installed)
    verify_mounts(config)
    profile = Path('/mnt/nix/var/nix/profiles/system')
    # Absolute store links resolve inside the target after chroot, not the live ISO.
    if not (profile.is_symlink() or profile.exists()):
        raise Stop('No installed system generation exists; finish the install stage first.')
    if not config.declarative_password and not sys.stdin.isatty():
        raise Stop('Account setup requires an interactive terminal.')
    commands = [['id', config.username]]
    if not config.declarative_password:
        commands.append(['passwd', config.username])
    for command in commands:
        run('nixos-enter', '--root', '/mnt', '--',
            '/nix/var/nix/profiles/system/sw/bin/' + command[0], *command[1:])
    status = run('nixos-enter', '--root', '/mnt', '--',
                 '/nix/var/nix/profiles/system/sw/bin/passwd', '--status', config.username, capture=True).split()
    if len(status) < 2 or status[:2] != [config.username, 'P']:
        raise Stop('The selected account does not have a usable password. Do not reboot.')
    print('Selected account has a usable password. Follow the reboot checklist.', flush=True)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--config', type=Path, default=Path.cwd(), help='Reviewed Git checkout root (default: current directory)')
    parser.add_argument('stage', choices=['preflight', 'plan', 'format', 'mounts', 'install', 'account'])
    args = parser.parse_args()
    try:
        live_environment()
        # Serialize installer stages; no persistent "passed" marker can bypass checks.
        with open('/run/nix-framework-installer.lock', 'w') as lock:
            fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
            if args.stage == 'account':
                account()
                return 0
            config = snapshot(args.config)
            if args.stage in ('preflight', 'plan'):
                evaluate(config)
                show_disk(config, fresh_storage(config))
                if args.stage == 'plan':
                    disko(config, dry=True)
            elif args.stage == 'format':
                format_disk(config)
            elif args.stage == 'mounts':
                verify_mounts(config)
            elif args.stage == 'install':
                install_system(config)
    except (Stop, OSError, ValueError, KeyError, subprocess.CalledProcessError, EOFError) as error:
        print(f'Installation stopped: {error}\nDo not rerun format to recover a failed install. See docs/install/storage.md.', file=sys.stderr)
        return 1
    return 0


if __name__ == '__main__':
    sys.exit(main())
