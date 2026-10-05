"""Persistent, non-secret binding between a formatted target and its source."""

import json
import os
from pathlib import Path
import tempfile

from common import Stop


RECORD = Path('/mnt/etc/nix-framework-installer.json')


def expected(config, disk, layout):
    return {
        'version': 1,
        'source_tree': config.source_tree,
        'base_commit': config.base_commit,
        'source_store_path': str(config.source) if config.source_tree else '',
        'disk_by_id': config.disk,
        'disk_serial': disk.serial,
        'disk_model': disk.model,
        'disk_bytes': disk.size,
        'layout_sha256': layout.fingerprint,
    }


def read():
    if RECORD.is_symlink():
        raise Stop('Refusing a symlink at the installation record path.')
    try:
        data = json.loads(RECORD.read_text())
    except (FileNotFoundError, ValueError) as error:
        raise Stop('Installation record missing or invalid; inspect/recover the target before install.') from error
    if not isinstance(data, dict) or data.get('version') != 1 or not data.get('source_tree'):
        raise Stop('Installation record is incomplete; inspect/recover the target.')
    return data


def verify(config, disk, layout, *, source=True):
    data = read()
    expected_data = expected(config, disk, layout)
    fields = ('version', 'disk_by_id', 'disk_serial', 'disk_model', 'disk_bytes', 'layout_sha256')
    if source:
        fields += ('source_tree', 'base_commit', 'source_store_path')
    if any(data.get(field) != expected_data[field] for field in fields):
        raise Stop('Installation record differs from selected source, disk, or storage layout; inspect before continuing.')
    return data


def create(config, disk, layout):
    if not config.source_tree or not config.base_commit:
        raise Stop('Cannot record an installation without a reviewed Git tree.')
    if RECORD.exists() or RECORD.is_symlink():
        verify(config, disk, layout)
        return
    if RECORD.parent.is_symlink():
        raise Stop('Refusing a symlink at the installation record directory.')
    RECORD.parent.mkdir(exist_ok=True)
    fd, name = tempfile.mkstemp(prefix='.installer-record-', dir=RECORD.parent)
    try:
        with os.fdopen(fd, 'w') as output:
            os.fchmod(output.fileno(), 0o600)
            json.dump(expected(config, disk, layout), output, sort_keys=True, indent=2)
            output.write('\n')
            output.flush()
            os.fsync(output.fileno())
        Path(name).replace(RECORD)
        directory_fd = os.open(RECORD.parent, os.O_RDONLY)
        try:
            os.fsync(directory_fd)
        finally:
            os.close(directory_fd)
    finally:
        if Path(name).exists():
            Path(name).unlink()
