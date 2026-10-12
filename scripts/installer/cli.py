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
import record
from storage import (check_partitions, disk_identity, fresh_storage, recover_mounts,
                     show_disk, verify_mounts)


def disko(config, dry=False):
    args = ['nix', 'run', f'{config.source}#disko', '--no-update-lock-file', '--no-write-lock-file', '--']
    if dry:
        args.append('--dry-run')
    run(*args, '--mode', 'destroy,format,mount', '--flake', config.flake)


def confirm(prompt, expected, *, missing_terminal, mismatch):
    """Require the exact phrase on an interactive terminal; never read it from a pipe."""
    if not sys.stdin.isatty():
        raise Stop(missing_terminal)
    print(f'{prompt} Type exactly: {expected}', flush=True)
    if input().strip() != expected:
        raise Stop(mismatch)


def format_disk(config):
    layout = evaluate(config)
    before = fresh_storage(config, layout)
    show_disk(config, before)
    confirm('ALL DATA ON THIS DISK WILL BE LOST.', f'ERASE {config.disk}',
            missing_terminal='Formatting requires an interactive terminal; no unattended confirmation option exists.',
            mismatch='Disk erase confirmation did not match; nothing was formatted.')
    if fresh_storage(config, layout) != before:
        raise Stop('Disk identity changed during confirmation; nothing was formatted.')
    disko(config)
    # Disko's mount phase orders entries by the mount points in
    # config.fileSystems, but the swap _mount entry is keyed by its device
    # path, so `--mode mount` never runs swapon (lib/default.nix mountOrder vs
    # lib/types/swap.nix; unfixed upstream as of disko 725ea35). Reconcile the
    # validated existing layout (never format again), activate its encrypted
    # swap, and retain the strict final mount/swap verification.
    disk = recover_mounts(config, layout)
    record.create(config, disk, layout)


def recover(config):
    layout = evaluate(config)
    disk = disk_identity(config)
    check_partitions(config, layout, disk)
    show_disk(config, disk)
    confirm('Open and mount this existing target only.', f'RECOVER {config.disk}',
            missing_terminal='Recovery requires an interactive terminal.',
            mismatch='Recovery confirmation did not match; no mapping or mount was opened.')
    if disk_identity(config) != disk:
        raise Stop('Disk identity changed during recovery confirmation.')

    def existing_record(mounted_disk):
        if record.RECORD.exists() or record.RECORD.is_symlink():
            # Disk and layout must match. A changed reviewed source is
            # re-bound by the install stage after explicit confirmation.
            record.verify(config, mounted_disk, layout, source=False)
        elif Path('/mnt/etc/NIXOS').exists() or Path('/mnt/etc/nixos').exists():
            raise Stop('An existing installation has no matching installer record; inspect it before recovery.')

    recovered_disk = recover_mounts(config, layout, after_root=existing_record)
    record.create(config, recovered_disk, layout)
    print('Existing target mounted and verified. Continue with install; never rerun format.', flush=True)


def copy_source(config, replace=False, parent=Path('/mnt/etc')):
    validate_source(config.source)
    target = parent / 'nixos'
    if parent.is_symlink() or target.is_symlink():
        raise Stop('Refusing a symlink at the target configuration path.')
    parent.mkdir(exist_ok=True)
    if target.exists():
        # Never silently mix a retry with an old configuration. Use the existing
        # target only if byte-for-byte identical; replacing a differing copy
        # requires the explicit source-change confirmation in install_system.
        comparison = subprocess.run(['diff', '-qr', '--no-dereference', str(config.source), str(target)],
                                    stdout=subprocess.PIPE, text=True)
        if comparison.returncode != 1:
            comparison.check_returncode()
            return target
        if not replace:
            raise Stop('Target configuration differs; preserve/review it before retrying.')
        shutil.rmtree(target)
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
    layout = evaluate(config)
    before = verify_mounts(config, layout)
    recorded = record.verify(config, before, layout, source=False)
    replace = not record.source_matches(config, recorded)
    if replace:
        # A reviewed fix after a failed install is a supported retry, but only
        # when the operator explicitly accepts the new tree for this target.
        print(f"Recorded source: commit {recorded.get('base_commit')}, tree {recorded.get('source_tree')}\n"
              f"Current source:  commit {config.base_commit}, tree {config.source_tree}", flush=True)
        confirm('The reviewed source changed since this target was formatted; the copied '
                'configuration on the target will be replaced and the record re-bound.',
                f'REPLACE SOURCE {config.source_tree[:12]}',
                missing_terminal='The reviewed source changed since format; rerun install interactively '
                                 'to accept it, or check out the recorded source.',
                mismatch='Source replacement confirmation did not match; nothing was copied or installed.')
    target = copy_source(config, replace=replace)
    installed = read_config(target)
    if (installed.hostname, installed.username, installed.disk, installed.declarative_password) != (
            config.hostname, config.username, config.disk, config.declarative_password):
        raise Stop('Copied configuration does not match the reviewed selection.')
    if verify_mounts(config, layout) != before:
        raise Stop('Disk identity changed before installation.')
    if replace:
        record.rebind(config, before, layout)
    run('nixos-install', '--root', '/mnt', '--flake', f'{target}#{config.hostname}', '--no-root-passwd')
    print('Installation finished. Run the account stage before rebooting.', flush=True)


def account():
    # The installed copy is authoritative, not an old variable or the live checkout.
    installed = Path('/mnt/etc/nixos')
    if installed.resolve() != installed:
        raise Stop('Installed configuration path must not contain a symlink.')
    config = read_config(installed)
    layout = evaluate(config)
    disk = verify_mounts(config, layout)
    record.verify(config, disk, layout, source=False)
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
    parser.add_argument('stage', choices=['preflight', 'plan', 'format', 'recover', 'mounts', 'install', 'account'])
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
                layout = evaluate(config)
                show_disk(config, fresh_storage(config, layout))
                if args.stage == 'plan':
                    disko(config, dry=True)
            elif args.stage == 'format':
                format_disk(config)
            elif args.stage == 'recover':
                recover(config)
            elif args.stage == 'mounts':
                verify_mounts(config, evaluate(config))
            elif args.stage == 'install':
                install_system(config)
    except (Stop, OSError, ValueError, KeyError, subprocess.CalledProcessError, EOFError) as error:
        print(f'Installation stopped: {error}\nDo not rerun format to recover a failed install. See docs/install/03-storage.md.', file=sys.stderr)
        return 1
    return 0


if __name__ == '__main__':
    sys.exit(main())
