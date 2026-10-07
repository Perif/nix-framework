"""Read-only disk and mounted-target checks used by every mutating stage."""

from dataclasses import dataclass
from pathlib import Path
import re
import stat

from common import Stop, query, run
from layout import ESP_GUID


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
            'PATH,TYPE,MAJ:MIN,SIZE,MODEL,SERIAL,MOUNTPOINTS,PARTTYPE,PARTLABEL,PARTN']
    if inverse:
        args.append('--inverse')
    if device is not None:
        args.extend(['--', str(device)])
    return query(*args)['blockdevices']


RAW_ESCAPE = re.compile(r'\\x([0-9a-fA-F]{2})')


def active_swaps():
    # swapon selects columns through --show, not --output (which abbreviates
    # --output-all). Raw output escapes whitespace in names as \xHH.
    rows = run('swapon', '--show=NAME,TYPE,SIZE', '--raw', '--noheadings', '--bytes',
               capture=True)
    swaps = []
    for row in rows.splitlines():
        name, kind, size = row.split()
        name = RAW_ESCAPE.sub(lambda match: chr(int(match.group(1), 16)), name)
        swaps.append({'name': name, 'type': kind, 'size': int(size)})
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


def fresh_storage(config, layout):
    disk = disk_identity(config, unused=True)
    if disk.size < layout.minimum_disk_bytes:
        raise Stop(f'Selected disk is too small for the evaluated layout: '
                   f'{disk.size} bytes available, at least {layout.minimum_disk_bytes} required.')
    if Path('/dev/mapper/cryptroot').exists():
        raise Stop('cryptroot mapping already exists. Inspect/recover; do not repeat format.')
    if vg_exists():
        raise Stop('A volume group named vg already exists. Resolve the collision before fresh formatting.')
    mounts = query('findmnt', '--json', '--output', 'TARGET')['filesystems']
    if any(n['target'] == '/mnt' or n['target'].startswith('/mnt/') for n in walk(mounts)):
        raise Stop('/mnt already contains mounted filesystems. Use mounts/install for a formatted target.')
    return disk


def vg_exists(name='vg'):
    groups = query('vgs', '--reportformat', 'json', '-o', 'vg_name')['report']
    return any(v['vg_name'].strip() == name for report in groups for v in report.get('vg', []))


def expected_device(config, layout, filesystem):
    """The only device a target of this filesystem type may be mounted from."""
    return (f'{config.disk}-part{layout.esp_partition}' if filesystem == 'vfat'
            else '/dev/mapper/vg-root')


def backing_disks(device):
    nodes = block_tree(device, inverse=True)
    return {n['maj:min'] for n in walk(nodes) if n['type'] == 'disk'}


def check_partitions(config, layout, disk):
    nodes = block_tree(config.disk)
    if len(nodes) != 1 or nodes[0]['maj:min'] != disk.number:
        raise Stop('Target disk identity changed during partition inspection.')
    parts = {int(n.get('partn') or 0): n for n in nodes[0].get('children', []) if n['type'] == 'part'}
    if set(parts) != {layout.esp_partition, layout.crypt_partition}:
        raise Stop('Target GPT partitions differ from the evaluated Disko layout.')
    for number, label in ((layout.esp_partition, 'disk-main-ESP'),
                          (layout.crypt_partition, 'disk-main-cryptroot')):
        node = parts[number]
        expected_path = Path(f'{config.disk}-part{number}').resolve(strict=True)
        if Path(node['path']).resolve(strict=True) != expected_path or node.get('partlabel') != label:
            raise Stop(f'Target partition {number} identity or GPT label differs from Disko.')
    if (parts[layout.esp_partition].get('parttype') or '').lower() != ESP_GUID:
        raise Stop('The target EFI partition has the wrong GPT type.')
    return Path(f'{config.disk}-part{layout.crypt_partition}').resolve(strict=True)


def check_encrypted_ancestry(disk):
    """Require each expected LV to have one PV under this disk's cryptroot."""
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


def check_esp_mount(config, layout, device):
    esp = Path(f'{config.disk}-part{layout.esp_partition}').resolve(strict=True)
    if Path(device).resolve(strict=True) != esp:
        raise Stop('The mounted EFI filesystem is not the evaluated ESP partition.')
    nodes = block_tree(esp)
    if (len(nodes) != 1 or nodes[0]['type'] != 'part'
            or (nodes[0].get('parttype') or '').lower() != ESP_GUID
            or nodes[0].get('partlabel') != 'disk-main-ESP'
            or int(nodes[0].get('partn') or 0) != layout.esp_partition):
        raise Stop('The EFI partition type, label, or number differs from Disko.')


def verify_mounts(config, layout):
    disk = disk_identity(config)
    check_partitions(config, layout, disk)
    tree = query('findmnt', '--json', '--submounts', '--mountpoint', '/mnt', '--output',
                 'TARGET,SOURCE,FSTYPE,FSROOT')['filesystems']
    mounts = {m['target']: m for m in walk(tree)}
    expected_mounts = layout.targets
    if set(mounts) != set(expected_mounts):
        raise Stop(f'Target mount set differs from layout: expected {sorted(expected_mounts)}, got {sorted(mounts)}')
    for target, (fs, root) in expected_mounts.items():
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
        if fs == 'vfat':
            check_esp_mount(config, layout, device)
    check_encrypted_ancestry(disk)
    swaps = active_swaps()
    expected_swap = str(Path('/dev/mapper/vg-swap').resolve())
    if not any(str(Path(s['name']).resolve()) == expected_swap and int(s['size']) >= layout.swap_bytes - 1024**3 for s in swaps):
        raise Stop(f'The encrypted {layout.swap_bytes // 1024**3} GiB installation swap is not active.')
    show_disk(config, disk)
    print('All target mounts and encrypted swap match the selected disk.', flush=True)
    return disk


def check_cryptroot(disk, partition):
    nodes = block_tree('/dev/mapper/cryptroot', inverse=True)
    if len(nodes) != 1 or nodes[0]['type'] != 'crypt':
        raise Stop('cryptroot mapping has an unexpected device type.')
    nodes = nodes[0].get('children', [])
    if (len(nodes) != 1 or nodes[0]['type'] != 'part'
            or Path(nodes[0]['path']).resolve(strict=True) != partition):
        raise Stop('cryptroot mapping is not on the selected LUKS partition.')
    nodes = nodes[0].get('children', [])
    if len(nodes) != 1 or nodes[0]['type'] != 'disk' or nodes[0]['maj:min'] != disk.number:
        raise Stop('cryptroot mapping belongs to a different disk.')


def check_vg_pv():
    reports = query('pvs', '--reportformat', 'json', '-o', 'pv_name,vg_name')['report']
    matching = [pv for report in reports for pv in report.get('pv', []) if pv['vg_name'] == 'vg']
    cryptroot = Path('/dev/mapper/cryptroot').resolve(strict=True)
    if len(matching) != 1 or Path(matching[0]['pv_name']).resolve(strict=True) != cryptroot:
        raise Stop('Volume group vg is not exclusively on the selected cryptroot mapping.')


def mounted_target_subset(config, layout, disk):
    mounts = query('findmnt', '--json', '--output', 'TARGET,SOURCE,FSTYPE,FSROOT')['filesystems']
    present = {m['target']: m for m in walk(mounts)
               if m['target'] == '/mnt' or m['target'].startswith('/mnt/')}
    unexpected = set(present) - set(layout.targets)
    if unexpected:
        raise Stop(f'Unexpected mount beneath /mnt: {sorted(unexpected)}')
    for target, m in present.items():
        fs, root = layout.targets[target]
        source = m['source'].split('[', 1)[0]
        if (m['fstype'], m['fsroot']) != (fs, root) or backing_disks(source) != {disk.number}:
            raise Stop(f'Existing mount at {target} does not match the selected layout.')
        if Path(source).resolve(strict=True) != Path(expected_device(config, layout, fs)).resolve(strict=True):
            raise Stop(f'Existing mount at {target} uses the wrong partition or LV.')
    return present


def refuse_unrelated_mounts(disk, layout):
    mounts = query('findmnt', '--json', '--output', 'TARGET,SOURCE')['filesystems']
    for mount in walk(mounts):
        target = mount['target']
        if target != '/mnt' and not target.startswith('/mnt/'):
            continue
        if target not in layout.targets:
            raise Stop(f'Unexpected mount beneath /mnt: {target}')
        source = mount['source'].split('[', 1)[0]
        if backing_disks(source) != {disk.number}:
            raise Stop(f'Unrelated disk is mounted at {target}; recovery stopped before opening LUKS.')


def recover_mounts(config, layout, after_root=None):
    """Open and mount only the confirmed existing target; never create storage."""
    disk = disk_identity(config)
    partition = check_partitions(config, layout, disk)
    show_disk(config, disk)
    refuse_unrelated_mounts(disk, layout)
    run('cryptsetup', 'isLuks', '--type', 'luks2', str(partition))
    if Path('/dev/mapper/cryptroot').exists():
        check_cryptroot(disk, partition)
    else:
        # A colliding VG on another disk must stop recovery before opening LUKS.
        if vg_exists():
            raise Stop('Volume group vg exists without this disk\'s cryptroot mapping.')
        run('cryptsetup', 'open', '--type', 'luks2', str(partition), 'cryptroot')
        check_cryptroot(disk, partition)
    check_vg_pv()
    for lv in ('root', 'swap'):
        run('lvchange', '-ay', f'/dev/vg/{lv}')
    check_encrypted_ancestry(disk)
    for path, expected_type in (('/dev/mapper/vg-root', 'btrfs'),
                                ('/dev/mapper/vg-swap', 'swap'),
                                (f'{config.disk}-part{layout.esp_partition}', 'vfat')):
        actual = run('blkid', '--probe', '--output', 'value', '--match-tag', 'TYPE', path,
                     capture=True)
        if actual != expected_type:
            raise Stop(f'Existing filesystem type at {path} is {actual!r}, expected {expected_type}.')
    present = mounted_target_subset(config, layout, disk)
    if '/mnt' not in present and any(target != '/mnt' for target in present):
        raise Stop('Child mounts exist without /mnt root; inspect mount stacking manually.')
    if '/mnt' in present and after_root is not None:
        after_root(disk)
    # Root is first; all other targets are ordered by path depth. Existing
    # correct mounts are retained, so this can finish a partial mount attempt.
    for target, fs, root in sorted(layout.mounts, key=lambda m: (m[0].count('/'), m[0])):
        if target in present:
            continue
        path = Path(target)
        if path.is_symlink() or any(parent.is_symlink() for parent in path.parents if parent != Path('/')):
            raise Stop(f'Refusing a symlink in target mount path {target}.')
        path.mkdir(parents=True, exist_ok=True)
        device = expected_device(config, layout, fs)
        options = list(layout.options[target])
        if fs == 'btrfs':
            options.insert(0, f'subvol={root}')
        run('mount', '-t', fs, '-o', ','.join(options), device, target)
        # Re-read the actual mount table after every change; a failed or
        # redirected mount must stop before touching the next target.
        present = mounted_target_subset(config, layout, disk)
        if target not in present:
            raise Stop(f'Mount did not appear at {target}.')
        if target == '/mnt' and after_root is not None:
            after_root(disk)
    expected_swap = Path('/dev/mapper/vg-swap').resolve(strict=True)
    swaps = active_swaps()
    for active in swaps:
        path = Path(active['name'])
        # Only another block device on the selected disk conflicts. Swap files
        # and devices that vanished are not probed with lsblk.
        if active['type'] != 'partition' or not path.exists():
            continue
        if path.resolve() != expected_swap and disk.number in backing_disks(path):
            raise Stop('A different swap device is active on the selected disk.')
    if not any(Path(s['name']).resolve() == expected_swap for s in swaps):
        run('swapon', '/dev/mapper/vg-swap')
    return verify_mounts(config, layout)
