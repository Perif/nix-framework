"""Persistent, non-secret binding between a formatted target and its source."""

import json
import os
from pathlib import Path
import tempfile

from common import Stop


RECORD = Path('/mnt/etc/nix-framework-installer.json')


SOURCE_FIELDS = ('source_tree', 'base_commit', 'source_store_path')


def source_fields(config):
    return {
        'source_tree': config.source_tree,
        'base_commit': config.base_commit,
        'source_store_path': str(config.source) if config.source_tree else '',
    }


def source_matches(config, data):
    """Whether a record still binds the currently reviewed source."""
    return all(data.get(field) == value for field, value in source_fields(config).items())


def expected(config, disk, layout):
    return {
        'version': 1,
        **source_fields(config),
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
        fields += SOURCE_FIELDS
    if any(data.get(field) != expected_data[field] for field in fields):
        raise Stop('Installation record differs from selected source, disk, or storage layout; inspect before continuing.')
    return data


def create(config, disk, layout):
    if not config.source_tree or not config.base_commit:
        raise Stop('Cannot record an installation without a reviewed Git tree.')
    if RECORD.exists() or RECORD.is_symlink():
        # An existing record keeps its source binding here. Only the install
        # stage re-binds a changed reviewed source, after explicit confirmation.
        verify(config, disk, layout, source=False)
        return
    write(expected(config, disk, layout))


def rebind(config, disk, layout):
    """Bind the existing record for this disk and layout to the current source."""
    verify(config, disk, layout, source=False)
    write(expected(config, disk, layout))


def write(data):
    if RECORD.parent.is_symlink():
        raise Stop('Refusing a symlink at the installation record directory.')
    RECORD.parent.mkdir(exist_ok=True)
    fd, name = tempfile.mkstemp(prefix='.installer-record-', dir=RECORD.parent)
    try:
        with os.fdopen(fd, 'w') as output:
            os.fchmod(output.fileno(), 0o600)
            json.dump(data, output, sort_keys=True, indent=2)
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
