"""The supported storage contract, derived from the evaluated Disko module."""

from dataclasses import dataclass
import hashlib
import json
import posixpath

from common import Stop, query


GIB = 1024 ** 3
ESP_GUID = 'c12a7328-f81f-11d2-ba4b-00a0c93ec93b'

# Project only JSON-safe, evaluated Disko fields. The full disko.devices value
# contains functions and scripts, so it cannot be serialized with --json.
PROJECTION = r'''d: {
  extraKinds = builtins.filter (n: d.${n} != {}) [ "bcachefs_filesystems" "mdadm" "zpool" "nodev" ];
  diskNames = builtins.attrNames d.disk;
  vgNames = builtins.attrNames d.lvm_vg;
  disk.main = {
    type = d.disk.main.type;
    device = d.disk.main.device;
    content = {
      type = d.disk.main.content.type;
      partitionNames = builtins.attrNames d.disk.main.content.partitions;
      partitions = builtins.mapAttrs (n: p: {
        type = p.type; size = p.size; index = p._index; label = p.label;
        content = if n == "ESP" then {
          type = p.content.type; format = p.content.format;
          mountpoint = p.content.mountpoint; mountOptions = p.content.mountOptions;
        } else {
          type = p.content.type; name = p.content.name;
          askPassword = p.content.askPassword;
          extraFormatArgs = p.content.extraFormatArgs;
          content = { type = p.content.content.type; vg = p.content.content.vg; };
        };
      }) d.disk.main.content.partitions;
    };
  };
  lvm_vg.vg = {
    type = d.lvm_vg.vg.type;
    lvNames = builtins.attrNames d.lvm_vg.vg.lvs;
    lvs = builtins.mapAttrs (n: lv: {
      size = lv.size;
      content = if n == "root" then {
        type = lv.content.type;
        subvolumes = builtins.mapAttrs (_: v: {
          mountpoint = v.mountpoint; mountOptions = v.mountOptions;
        }) lv.content.subvolumes;
      } else { type = lv.content.type; resumeDevice = lv.content.resumeDevice; };
    }) d.lvm_vg.vg.lvs;
  };
}'''


def gib_size(value):
    if (not isinstance(value, str) or not value.endswith('G')
            or not value[:-1].isdigit() or int(value[:-1]) <= 0):
        raise Stop(f'Unsupported Disko size {value!r}; use a positive fixed whole-GiB size.')
    return int(value[:-1]) * GIB


def canonical_absolute_path(value, *, allow_root=True):
    return (isinstance(value, str) and value.startswith('/')
            and not value.startswith('//') and '\0' not in value
            and posixpath.normpath(value) == value
            and (allow_root or value != '/'))


@dataclass(frozen=True)
class Layout:
    mounts: tuple  # (target, filesystem, filesystem root)
    mount_options: tuple  # (target, tuple of mount option strings)
    esp_partition: int
    crypt_partition: int
    esp_bytes: int
    swap_bytes: int
    minimum_disk_bytes: int
    fingerprint: str

    @property
    def targets(self):
        return {target: (filesystem, root) for target, filesystem, root in self.mounts}

    @property
    def options(self):
        return dict(self.mount_options)


def from_disko(devices, selected_disk):
    """Accept only the topology recovery and verification know how to handle."""
    try:
        disk = devices['disk']['main']
        gpt = disk['content']
        partitions = gpt['partitions']
        esp = partitions['ESP']
        crypt = partitions['cryptroot']
        luks = crypt['content']
        pv = luks['content']
        vg = devices['lvm_vg']['vg']
        root = vg['lvs']['root']
        swap = vg['lvs']['swap']
        subvolumes = root['content']['subvolumes']
    except (KeyError, TypeError) as error:
        raise Stop('Unsupported Disko topology: expected ESP, cryptroot, vg-root, and vg-swap.') from error
    if (devices['extraKinds'] or devices['diskNames'] != ['main']
            or devices['vgNames'] != ['vg']
            or gpt['partitionNames'] != ['ESP', 'cryptroot']
            or vg['lvNames'] != ['root', 'swap']
            or disk['type'] != 'disk' or disk['device'] != selected_disk
            or gpt['type'] != 'gpt' or esp['type'] != 'EF00'
            or esp['index'] != 1 or crypt['index'] != 2
            or esp['label'] != 'disk-main-ESP'
            or crypt['label'] != 'disk-main-cryptroot'
            or esp['content']['type'] != 'filesystem' or esp['content']['format'] != 'vfat'
            or esp['content']['mountpoint'] != '/boot'
            or crypt['size'] != '100%' or luks['type'] != 'luks'
            or luks['name'] != 'cryptroot' or not luks.get('askPassword')
            or '--type' not in luks.get('extraFormatArgs', [])
            or 'luks2' not in luks.get('extraFormatArgs', [])
            or pv['type'] != 'lvm_pv' or pv['vg'] != 'vg'
            or vg['type'] != 'lvm_vg' or root['content']['type'] != 'btrfs'
            or root['size'] != '100%FREE' or swap['content']['type'] != 'swap'
            or not swap['content'].get('resumeDevice')):
        raise Stop('Unsupported Disko topology; review the installer before changing the storage layout.')
    mounts = [('/mnt/boot', 'vfat', '/')]
    options = {'/mnt/boot': tuple(esp['content']['mountOptions'])}
    for subvolume, spec in subvolumes.items():
        if not canonical_absolute_path(subvolume, allow_root=False):
            raise Stop('Every supported Btrfs subvolume needs a canonical absolute name.')
        mountpoint = spec.get('mountpoint')
        if not canonical_absolute_path(mountpoint):
            raise Stop('Every supported Btrfs mount point needs a canonical absolute path.')
        target = '/mnt' if mountpoint == '/' else '/mnt' + mountpoint
        mounts.append((target, 'btrfs', subvolume))
        options[target] = tuple(spec['mountOptions'])
    targets = {target for target, _, _ in mounts}
    if len(targets) != len(mounts) or '/mnt' not in targets or '/mnt/nix' not in targets:
        raise Stop('Disko must define distinct root and Nix mount points.')
    # Which further subvolumes exist is the reviewed disk.nix's decision; the
    # evaluated layout is verified as-is rather than against a second copy.
    esp_bytes = gib_size(esp['size'])
    swap_bytes = gib_size(swap['size'])
    # This is a feasibility floor, not a promise that every future build fits.
    minimum = esp_bytes + swap_bytes + 16 * GIB
    canonical = json.dumps(devices, sort_keys=True, separators=(',', ':'))
    return Layout(tuple(sorted(mounts)), tuple(sorted(options.items())),
                  esp['index'], crypt['index'], esp_bytes, swap_bytes,
                  minimum, hashlib.sha256(canonical.encode()).hexdigest())


def evaluate_layout(config):
    devices = query('nix', 'eval', '--json',
                    f'{config.source}#nixosConfigurations.{config.hostname}.config.disko.devices',
                    '--no-update-lock-file', '--no-write-lock-file', '--apply', PROJECTION)
    return from_disko(devices, config.disk)
