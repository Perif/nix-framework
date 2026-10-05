"""Read-only disk and mounted-target checks used by every mutating stage."""

from dataclasses import dataclass
from pathlib import Path
import stat

from common import Stop, query, run


MOUNTS = {
    '/mnt': ('btrfs', '/root'),
    '/mnt/boot': ('vfat', '/'),
    '/mnt/home': ('btrfs', '/home'),
    '/mnt/nix': ('btrfs', '/nix'),
    '/mnt/var/log': ('btrfs', '/log'),
    '/mnt/.snapshots': ('btrfs', '/snapshots'),
    '/mnt/var/lib/private/ollama': ('btrfs', '/ollama'),
}


def walk(nodes):
    for node in nodes:
        yield node
        yield from walk(node.get('children', []))


@dataclass(frozen=True)
class Disk:
    path: str
    number: str
    serial: str
    size: int
    model: str


def block_tree(device=None, inverse=False):
    # JSON children require --tree when NAME is not one of the selected columns.
    args = ['lsblk', '--json', '--tree', '--bytes', '--output',
            'PATH,TYPE,MAJ:MIN,SIZE,MODEL,SERIAL,MOUNTPOINTS']
    if inverse:
        args.append('--inverse')
    if device is not None:
        args.extend(['--', str(device)])
    return query(*args)['blockdevices']


def active_swaps():
    # swapon has no JSON mode. Raw output escapes whitespace in device names.
    rows = run('swapon', '--show', '--raw', '--noheadings', '--bytes',
               '--output', 'NAME,SIZE', capture=True)
    swaps = []
    for row in rows.splitlines():
        name, size = row.split()
        swaps.append({'name': name, 'size': int(size)})
    return swaps


def disk_identity(config, *, unused=False):
    path = Path(config.disk).resolve(strict=True)
    if not stat.S_ISBLK(path.stat().st_mode):
        raise Stop('The configured device is not a block device.')
    nodes = block_tree(path)
    if len(nodes) != 1 or nodes[0]['type'] != 'disk':
        raise Stop('The configured device must be a whole disk, not a partition or mapper.')
    node = nodes[0]
    disk = Disk(str(path), node['maj:min'], (node.get('serial') or '').strip(),
                int(node['size']), (node.get('model') or '').strip())
    if not disk.serial or not disk.model:
        raise Stop('Cannot verify disk model/serial; inspect the device before proceeding.')
    if unused:
        for child in walk(nodes):
            if any(child.get('mountpoints') or []):
                raise Stop('Target disk or a descendant is mounted/in use (including swap).')
            if child['type'] not in ('disk', 'part'):
                raise Stop('Target has active mappings; use the recovery guide, not format.')
        swaps = active_swaps()
        descendants = {str(Path(n['path']).resolve()) for n in walk(nodes)}
        if any(str(Path(s['name']).resolve()) in descendants for s in swaps):
            raise Stop('Target disk has active swap.')
    return disk


def show_disk(config, disk):
    print(f"Target: {config.disk}\nDevice: {disk.path} ({disk.number})\n"
          f"Model: {disk.model}\nSerial: {disk.serial}\nBytes: {disk.size}", flush=True)


def fresh_storage(config):
    disk = disk_identity(config, unused=True)
    if Path('/dev/mapper/cryptroot').exists():
        raise Stop('cryptroot mapping already exists. Inspect/recover; do not repeat format.')
    groups = query('vgs', '--reportformat', 'json', '-o', 'vg_name')['report']
    if any(v['vg_name'].strip() == 'vg' for report in groups for v in report.get('vg', [])):
        raise Stop('A volume group named vg already exists. Resolve the collision before fresh formatting.')
    mounts = query('findmnt', '--json', '--output', 'TARGET')['filesystems']
    if any(n['target'] == '/mnt' or n['target'].startswith('/mnt/') for n in walk(mounts)):
        raise Stop('/mnt already contains mounted filesystems. Use mounts/install for a formatted target.')
    return disk


def backing_disks(device):
    nodes = block_tree(device, inverse=True)
    return {n['maj:min'] for n in walk(nodes) if n['type'] == 'disk'}


def verify_mounts(config):
    disk = disk_identity(config)
    tree = query('findmnt', '--json', '--submounts', '--mountpoint', '/mnt', '--output',
                 'TARGET,SOURCE,FSTYPE,FSROOT')['filesystems']
    mounts = {m['target']: m for m in walk(tree)}
    if set(mounts) != set(MOUNTS):
        raise Stop(f'Target mount set differs from layout: expected {sorted(MOUNTS)}, got {sorted(mounts)}')
    for target, (fs, root) in MOUNTS.items():
        if str(Path(target).resolve()) != target:
            raise Stop(f'Target path contains a symlink: {target}')
        m = mounts[target]
        if (m['fstype'], m['fsroot']) != (fs, root):
            raise Stop(f'Wrong filesystem/subvolume at {target}.')
        device = m['source'].split('[', 1)[0]
        if backing_disks(device) != {disk.number}:
            raise Stop(f'{target} is backed by a different physical disk.')
        if fs == 'btrfs' and Path(device).resolve() != Path('/dev/mapper/vg-root').resolve():
            raise Stop(f'{target} is not on the expected root LV.')
    # This layout has one encrypted PV, not a VG spanning encrypted and plain
    # partitions. Require every ancestor in the exact chain, not any crypt node.
    for lv in ('/dev/mapper/vg-root', '/dev/mapper/vg-swap'):
        nodes = block_tree(lv, inverse=True)
        for kind in ('lvm', 'crypt', 'part', 'disk'):
            if len(nodes) != 1 or nodes[0]['type'] != kind:
                raise Stop(f'{lv} is not the expected single-PV encrypted layout.')
            node = nodes[0]
            if kind == 'crypt' and Path(node['path']).resolve() != Path('/dev/mapper/cryptroot').resolve():
                raise Stop(f'{lv} is not beneath cryptroot.')
            if kind == 'disk' and node['maj:min'] != disk.number:
                raise Stop(f'{lv} belongs to another disk.')
            nodes = node.get('children', [])
        if nodes:
            raise Stop(f'Unexpected storage ancestors beneath {lv}.')
    swaps = active_swaps()
    expected_swap = str(Path('/dev/mapper/vg-swap').resolve())
    if not any(str(Path(s['name']).resolve()) == expected_swap and int(s['size']) >= 39 * 1024**3 for s in swaps):
        raise Stop('The encrypted 40 GiB installation swap is not active.')
    show_disk(config, disk)
    print('All target mounts and encrypted swap match the selected disk.', flush=True)
    return disk
