"""Exercise installer safety gates with synthetic devices and command results only."""

import argparse
from copy import deepcopy
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest
from unittest.mock import mock_open, patch


parser = argparse.ArgumentParser()
parser.add_argument(
    "--helpers", type=Path,
    default=Path(__file__).resolve().parents[1] / "scripts/installer",
)
args, test_args = parser.parse_known_args()
sys.path.insert(0, str(args.helpers.resolve()))
import common  # noqa: E402
import storage  # noqa: E402
import cli  # noqa: E402


VALID_SETTINGS = {
    "hostname": "framework-pro",
    "username": "owner",
    "diskDevice": "/dev/disk/by-id/nvme-Samsung_990_SERIAL",
    "timeZone": "America/Chicago",
    "secureBoot": False,
    "declarativePassword": False,
}
SIZE = 2_000_000_000_000
SWAP_SIZE = 40 * 1024**3


def config(source=Path("/nix/store/reviewed-source")):
    return common.Config(source, "framework-pro", "owner", VALID_SETTINGS["diskDevice"])


def disk(number="259:0", serial="SERIAL"):
    return storage.Disk("/dev/nvme0n1", number, serial, SIZE, "Samsung 990 EVO Plus")


class SettingsAndEvaluation(unittest.TestCase):
    def test_swap_inventory_empty_active_and_invalid_output(self):
        for output, expected in (
            ('', []),
            ('/dev/dm-2 42949668864\n/dev/zram0 8589930496',
             [{'name': '/dev/dm-2', 'size': 42949668864},
              {'name': '/dev/zram0', 'size': 8589930496}]),
        ):
            with patch.object(storage, 'run', return_value=output):
                self.assertEqual(storage.active_swaps(), expected)
        with patch.object(storage, 'run', return_value='/dev/dm-2 unknown'):
            with self.assertRaises(ValueError):
                storage.active_swaps()

    def test_valid_settings_and_unsafe_selections(self):
        with patch.object(common, "query", return_value=VALID_SETTINGS):
            self.assertEqual(common.read_config(Path("/reviewed")), config(Path("/reviewed")))
        with patch.object(common, "query", return_value={**VALID_SETTINGS, "declarativePassword": True}):
            self.assertTrue(common.read_config(Path("/reviewed")).declarative_password)

        cases = (
            ("diskDevice", "/dev/disk/by-id/REPLACE-WITH-YOUR-NVME-ID"),
            ("diskDevice", "/dev/disk/by-id/nvme-SERIAL-part2"),
            ("diskDevice", "/dev/nvme0n1"),
            ("username", "root"),
            ("username", "bad user"),
            ("timeZone", None),
            ("secureBoot", True),
        )
        for field, value in cases:
            with self.subTest(field=field, value=value):
                settings = {**VALID_SETTINGS, field: value}
                with patch.object(common, "query", return_value=settings):
                    with self.assertRaises(common.Stop):
                        common.read_config(Path("/reviewed"))

    def test_evaluated_disko_target_must_match_reviewed_disk(self):
        with patch.object(common, "run", side_effect=["/nix/store/system.drv", "/dev/disk/by-id/other"]):
            with self.assertRaisesRegex(common.Stop, "Disko target differs"):
                common.evaluate(config())

    def test_live_environment_rejects_installed_system_or_non_uefi_boot(self):
        with patch.object(common.sys, "platform", "linux"), patch.object(common.os, "geteuid", return_value=0), \
             patch.object(common.Path, "is_dir", return_value=True):
            with patch.object(common.Path, "read_text", return_value='ID=nixos\n'), \
                 patch.object(common, "query", side_effect=lambda *cmd: {
                     "filesystems": [{"fstype": "ext4" if "/" in cmd else "iso9660"}]},):
                with self.assertRaisesRegex(common.Stop, "standard NixOS ISO"):
                    common.live_environment()
            with patch.object(common.Path, "read_text", return_value='ID=ubuntu\n'):
                with self.assertRaisesRegex(common.Stop, "NixOS installer ISO"):
                    common.live_environment()
        with patch.object(common.sys, "platform", "linux"), patch.object(common.os, "geteuid", return_value=0), \
             patch.object(common.Path, "read_text", return_value='ID=nixos\n'), \
             patch.object(common.Path, "is_dir", return_value=False):
            with self.assertRaisesRegex(common.Stop, "UEFI"):
                common.live_environment()

    def test_snapshot_rejects_unstaged_edits_before_nix_metadata(self):
        with tempfile.TemporaryDirectory() as path:
            directory = Path(path)

            def fake_run(*command, **_):
                if command[-2:] == ("rev-parse", "--show-toplevel"):
                    return str(directory)
                if "diff" in command:
                    raise subprocess.CalledProcessError(1, command)
                return None

            with patch.object(common, "run", side_effect=fake_run), \
                 patch.object(common, "query") as metadata:
                with self.assertRaisesRegex(common.Stop, "Unstaged tracked edits"):
                    common.snapshot(directory)
                metadata.assert_not_called()

    def test_snapshot_rejects_index_change_during_metadata_capture(self):
        with tempfile.TemporaryDirectory() as path:
            directory = Path(path)
            trees = iter(("reviewed-tree", "changed-tree"))

            def fake_run(*command, **_):
                if command[-2:] == ("rev-parse", "--show-toplevel"):
                    return str(directory)
                if command[-1] == "write-tree":
                    return next(trees)
                if command[-2:] == ("rev-parse", "HEAD"):
                    return "base-commit"
                return None

            with patch.object(common, "run", side_effect=fake_run), \
                 patch.object(common, "query", return_value={"path": "/nix/store/source"}) as metadata, \
                 patch.object(common, "read_config") as read:
                with self.assertRaisesRegex(common.Stop, "staged configuration changed"):
                    common.snapshot(directory)
                metadata.assert_called_once()
                read.assert_not_called()

    def test_source_rejects_settings_or_module_symlink_before_copy(self):
        with tempfile.TemporaryDirectory() as path:
            root = Path(path)
            outside = root / "outside.nix"
            outside.write_text("{ }")
            for relative in (Path("settings.nix"), Path("modules/nixos/base.nix")):
                with self.subTest(relative=str(relative)):
                    source = root / ("source-" + relative.name)
                    source.mkdir()
                    link = source / relative
                    link.parent.mkdir(parents=True, exist_ok=True)
                    link.symlink_to(outside)
                    selected = config(source)
                    with self.assertRaisesRegex(common.Stop, "Source symlinks"):
                        common.validate_source(source)
                    # copy_source must reject this before touching /mnt.
                    with self.assertRaisesRegex(common.Stop, "Source symlinks"):
                        cli.copy_source(selected)


class FreshStorage(unittest.TestCase):
    def setUp(self):
        temp = tempfile.TemporaryDirectory()
        self.addCleanup(temp.cleanup)
        self.link = Path(temp.name) / "chosen-disk"
        self.link.symlink_to("/dev/null")
        self.chosen = common.Config(Path(temp.name), "framework-pro", "owner", str(self.link))

    def lsblk(self, children=None, kind="disk"):
        return {"blockdevices": [{
            "path": "/dev/null", "type": kind, "maj:min": "259:0", "size": SIZE,
            "model": "Samsung 990 EVO Plus", "serial": "SERIAL", "mountpoints": [],
            "children": children or [],
        }]}

    def test_whole_disk_and_active_child_guards(self):
        with patch.object(storage.stat, "S_ISBLK", return_value=True):
            with patch.object(storage, "query", return_value=self.lsblk(kind="part")):
                with self.assertRaisesRegex(common.Stop, "whole disk"):
                    storage.disk_identity(self.chosen)
            mounted = [{"path": "/dev/nvme0n1p1", "type": "part", "mountpoints": ["/boot"]}]
            with patch.object(storage, "query", return_value=self.lsblk(mounted)):
                with self.assertRaisesRegex(common.Stop, "mounted/in use"):
                    storage.disk_identity(self.chosen, unused=True)
            mapped = [{"path": "/dev/mapper/cryptroot", "type": "crypt", "mountpoints": []}]
            with patch.object(storage, "query", return_value=self.lsblk(mapped)):
                with self.assertRaisesRegex(common.Stop, "active mappings"):
                    storage.disk_identity(self.chosen, unused=True)

    def test_existing_crypt_mapping_or_volume_group_blocks_format(self):
        with patch.object(storage, "disk_identity", return_value=disk()):
            with patch.object(storage.Path, "exists", return_value=True):
                with self.assertRaisesRegex(common.Stop, "cryptroot mapping"):
                    storage.fresh_storage(config())
            with patch.object(storage.Path, "exists", return_value=False):
                with patch.object(storage, "query", return_value={"report": [{"vg": [{"vg_name": "vg"}]}]}):
                    with self.assertRaisesRegex(common.Stop, "volume group"):
                        storage.fresh_storage(config())


class MountedTarget(unittest.TestCase):
    def setUp(self):
        self.selected = disk()
        self.mounts = []
        for target, (fstype, fsroot) in storage.MOUNTS.items():
            self.mounts.append({
                "target": target,
                "source": "/dev/mapper/vg-root" if fstype == "btrfs" else "/dev/nvme0n1p1",
                "fstype": fstype,
                "fsroot": fsroot,
            })
        self.swaps = [{"name": "/dev/mapper/vg-swap", "size": SWAP_SIZE}]

    def query(self, *command):
        if command[0] == "findmnt":
            return {"filesystems": deepcopy(self.mounts)}
        if command[0] == "swapon":
            return {"swapdevices": deepcopy(self.swaps)}
        if command[0] == "lsblk":
            device = command[-1]
            return {"blockdevices": [{"path": device, "type": "lvm", "maj:min": "253:1", "children": [
                {"path": str(Path("/dev/mapper/cryptroot").resolve()), "type": "crypt", "maj:min": "253:0", "children": [
                    {"path": "/dev/nvme0n1p2", "type": "part", "maj:min": "259:2", "children": [
                        {"path": "/dev/nvme0n1", "type": "disk", "maj:min": self.selected.number}
                    ]}
                ]},
            ]}]}
        raise AssertionError(f"Unexpected fake query: {command}")

    def verify(self, backing=None):
        with patch.object(storage, "disk_identity", return_value=self.selected), \
             patch.object(storage, "query", side_effect=self.query), \
             patch.object(storage, "active_swaps", side_effect=lambda: deepcopy(self.swaps)), \
             patch.object(storage, "backing_disks", side_effect=backing or (lambda _: {self.selected.number})), \
             patch.object(storage, "show_disk"):
            return storage.verify_mounts(config())

    def test_mixed_encrypted_and_plain_pvs_are_rejected(self):
        original = self.query
        def mixed(*command):
            result = original(*command)
            if command[0] == "lsblk":
                result["blockdevices"][0]["children"].append(
                    {"path": "/dev/nvme0n1p3", "type": "part", "maj:min": "259:3"})
            return result
        with patch.object(self, "query", side_effect=mixed):
            with self.assertRaisesRegex(common.Stop, "single-PV encrypted"):
                self.verify()

    def test_valid_layout_is_accepted(self):
        self.assertEqual(self.verify(), self.selected)

    def test_wrong_disk_is_rejected(self):
        with self.assertRaisesRegex(common.Stop, "different physical disk"):
            self.verify(backing=lambda _: {"259:9"})

    def test_wrong_subvolume_missing_or_extra_mount_is_rejected(self):
        for change in ("subvolume", "missing", "extra"):
            with self.subTest(change=change):
                saved = deepcopy(self.mounts)
                try:
                    if change == "subvolume":
                        next(m for m in self.mounts if m["target"] == "/mnt/home")["fsroot"] = "/root"
                    elif change == "missing":
                        self.mounts = [m for m in self.mounts if m["target"] != "/mnt/nix"]
                    else:
                        self.mounts.append({"target": "/mnt/extra", "source": "/dev/mapper/vg-root",
                                            "fstype": "btrfs", "fsroot": "/extra"})
                    with self.assertRaises(common.Stop):
                        self.verify()
                finally:
                    self.mounts = saved

    def test_missing_or_wrong_swap_is_rejected(self):
        for swaps in ([], [{"name": "/dev/mapper/other-swap", "size": SWAP_SIZE}],
                      [{"name": "/dev/mapper/vg-swap", "size": 1024**3}]):
            with self.subTest(swaps=swaps):
                self.swaps = swaps
                with self.assertRaisesRegex(common.Stop, "swap is not active"):
                    self.verify()


class StageOrdering(unittest.TestCase):
    def format_with(self, *, tty=True, answer=None, disks=None, disko_error=None):
        selected = config()
        answer = answer if answer is not None else f"ERASE {selected.disk}"
        disks = disks or [disk(), disk()]
        with patch.object(cli, "evaluate"), patch.object(cli, "fresh_storage", side_effect=disks), \
             patch.object(cli, "show_disk"), patch.object(cli.sys.stdin, "isatty", return_value=tty), \
             patch("builtins.input", return_value=answer), patch.object(cli, "disko", side_effect=disko_error) as format_run, \
             patch.object(cli, "verify_mounts") as mounts:
            try:
                cli.format_disk(selected)
            except (common.Stop, subprocess.CalledProcessError):
                pass
            return format_run.call_count, mounts.call_count

    def test_format_refuses_nonterminal_or_wrong_confirmation(self):
        self.assertEqual(self.format_with(tty=False), (0, 0))
        self.assertEqual(self.format_with(answer="ERASE /dev/disk/by-id/other"), (0, 0))

    def test_disk_identity_change_blocks_format(self):
        self.assertEqual(self.format_with(disks=[disk(), disk(serial="CHANGED")]), (0, 0))

    def test_failed_format_command_stops_before_mount_success(self):
        error = subprocess.CalledProcessError(1, ["nix", "run", "disko"])
        self.assertEqual(self.format_with(disko_error=error), (1, 0))

    def test_install_requires_verified_mounts_before_copy_or_install(self):
        with patch.object(cli, "evaluate"), \
             patch.object(cli, "verify_mounts", side_effect=common.Stop("wrong disk")), \
             patch.object(cli, "copy_source") as copy_source, patch.object(cli, "run") as run:
            with self.assertRaises(common.Stop):
                cli.install_system(config())
            copy_source.assert_not_called()
            run.assert_not_called()

    def test_install_rejects_copied_settings_or_disk_change(self):
        selected = config()
        target = Path("/mnt/etc/nixos")
        wrong_user = common.Config(target, selected.hostname, "someone-else", selected.disk)
        with patch.object(cli, "evaluate"), patch.object(cli, "verify_mounts", return_value=disk()), \
             patch.object(cli, "copy_source", return_value=target), \
             patch.object(cli, "read_config", return_value=wrong_user), patch.object(cli, "run") as run:
            with self.assertRaisesRegex(common.Stop, "Copied configuration"):
                cli.install_system(selected)
            run.assert_not_called()

        installed = common.Config(target, selected.hostname, selected.username, selected.disk)
        with patch.object(cli, "evaluate"), \
             patch.object(cli, "verify_mounts", side_effect=[disk(), disk(serial="CHANGED")]), \
             patch.object(cli, "copy_source", return_value=target), \
             patch.object(cli, "read_config", return_value=installed), patch.object(cli, "run") as run:
            with self.assertRaisesRegex(common.Stop, "Disk identity changed"):
                cli.install_system(selected)
            run.assert_not_called()

    def test_account_reads_installed_copy_and_never_falls_back_to_root(self):
        installed = config(Path("/mnt/etc/nixos"))
        with patch.object(cli, "read_config", return_value=installed) as read, \
             patch.object(cli, "verify_mounts"), patch.object(cli.Path, "exists", return_value=True), \
             patch.object(cli.sys.stdin, "isatty", return_value=True), \
             patch.object(cli, "run", return_value="owner P 2026-10-04 0 99999 7 -1") as run:
            cli.account()
        read.assert_called_once_with(Path("/mnt/etc/nixos"))
        self.assertEqual(run.call_count, 3)
        entered = [entry.args for entry in run.call_args_list]
        self.assertTrue(all(argv[:4] == ("nixos-enter", "--root", "/mnt", "--") for argv in entered))
        self.assertTrue(all("-c" not in argv and argv[-1] == "owner" for argv in entered))
        self.assertEqual([Path(argv[4]).name for argv in entered], ["id", "passwd", "passwd"])
        self.assertEqual(entered[-1][-2:], ("--status", "owner"))
        self.assertTrue(run.call_args_list[-1].kwargs.get("capture"))

    def test_account_stops_on_failed_or_locked_status(self):
        installed = config(Path("/mnt/etc/nixos"))
        with patch.object(cli, "read_config", return_value=installed), \
             patch.object(cli, "verify_mounts"), patch.object(cli.Path, "exists", return_value=True), \
             patch.object(cli.sys.stdin, "isatty", return_value=True), \
             patch.object(cli, "run", side_effect=[None, subprocess.CalledProcessError(1, "passwd")]) as run:
            with self.assertRaises(subprocess.CalledProcessError):
                cli.account()
            self.assertEqual(run.call_count, 2)  # Never treat a failed password change as success.
        with patch.object(cli, "read_config", return_value=installed), \
             patch.object(cli, "verify_mounts"), patch.object(cli.Path, "exists", return_value=True), \
             patch.object(cli.sys.stdin, "isatty", return_value=True), \
             patch.object(cli, "run", return_value="owner L 2026-10-04 0 99999 7 -1") as run:
            with self.assertRaisesRegex(common.Stop, "usable password"):
                cli.account()
            self.assertEqual(run.call_count, 3)

    def test_declared_password_is_verified_without_interactive_change(self):
        installed = common.Config(Path("/mnt/etc/nixos"), "framework-pro", "owner",
                                  VALID_SETTINGS["diskDevice"], True)
        with patch.object(cli, "read_config", return_value=installed), \
             patch.object(cli, "verify_mounts"), patch.object(cli.Path, "exists", return_value=True), \
             patch.object(cli.sys.stdin, "isatty", return_value=False), \
             patch.object(cli, "run", return_value="owner P 2026-10-04 0 99999 7 -1") as run:
            cli.account()
        self.assertEqual(run.call_count, 2)
        commands = [entry.args for entry in run.call_args_list]
        self.assertEqual(Path(commands[0][4]).name, "id")
        self.assertEqual(commands[1][-2:], ("--status", "owner"))
        self.assertFalse(any(Path(command[4]).name == "passwd" and "--status" not in command
                             for command in commands))

    def test_account_accepts_dangling_live_store_profile_symlink(self):
        installed = common.Config(Path("/mnt/etc/nixos"), "framework-pro", "owner",
                                  VALID_SETTINGS["diskDevice"], True)
        profile = Path("/mnt/nix/var/nix/profiles/system")
        with patch.object(cli, "read_config", return_value=installed), \
             patch.object(cli, "verify_mounts"), \
             patch.object(cli.Path, "is_symlink", autospec=True, side_effect=lambda path: path == profile), \
             patch.object(cli.Path, "exists", return_value=False), \
             patch.object(cli.sys.stdin, "isatty", return_value=False), \
             patch.object(cli, "run", return_value="owner P 2026-10-04 0 99999 7 -1") as run:
            cli.account()
        self.assertEqual(run.call_count, 2)
        self.assertEqual(run.call_args_list[-1].args[-2:], ("--status", "owner"))

    def test_preflight_requires_fresh_storage_before_reporting_success(self):
        selected = config()
        with patch.object(cli.sys, "argv", ["installer", "preflight"]), \
             patch.object(cli, "live_environment"), patch("builtins.open", mock_open()), \
             patch.object(cli.fcntl, "flock"), patch.object(cli, "snapshot", return_value=selected), \
             patch.object(cli, "evaluate"), patch.object(cli, "fresh_storage", side_effect=common.Stop("in use")), \
             patch.object(cli, "show_disk") as show:
            self.assertEqual(cli.main(), 1)
            show.assert_not_called()


if __name__ == "__main__":
    unittest.main(argv=[__file__, *test_args])
