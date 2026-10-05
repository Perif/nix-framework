"""Read-only integration checks for the real Linux utilities used by the installer.

Run outside the Nix build sandbox on a Linux host. No device is opened for
writing, mounted, formatted, activated as swap, or used as an install target.
"""

import argparse
from pathlib import Path
import sys
import unittest


parser = argparse.ArgumentParser()
parser.add_argument('--helpers', type=Path, required=True)
args, test_args = parser.parse_known_args()
sys.path.insert(0, str(args.helpers.resolve()))
import common  # noqa: E402
import storage  # noqa: E402


@unittest.skipUnless(sys.platform == 'linux', 'Linux utility contracts')
class LinuxCommands(unittest.TestCase):
    def test_lsblk_schema_and_device_query(self):
        nodes = storage.block_tree()
        self.assertTrue(nodes, 'Runner must expose a block-device inventory')
        for node in storage.walk(nodes):
            self.assertTrue({'path', 'type', 'maj:min', 'size', 'model',
                             'serial', 'mountpoints', 'parttype', 'partlabel',
                             'partn'} <= node.keys())
            self.assertIsInstance(node['mountpoints'], list)
            self.assertGreaterEqual(int(node['size']), 0)
        # Exercise inverse-tree parsing on a device exposed by this host.
        available = next((n for n in storage.walk(nodes) if Path(n['path']).exists()), None)
        if available is not None:
            inverse = storage.block_tree(available['path'], inverse=True)
            self.assertIn(available['maj:min'], {n['maj:min'] for n in storage.walk(inverse)})

    def test_findmnt_schema(self):
        data = common.query('findmnt', '--json', '--submounts', '--mountpoint', '/',
                            '--output', 'TARGET,SOURCE,FSTYPE,FSROOT')['filesystems']
        self.assertEqual(data[0]['target'], '/')
        self.assertGreater(len(list(storage.walk(data))), 1)
        for node in storage.walk(data):
            self.assertTrue({'target', 'source', 'fstype', 'fsroot'} <= node.keys())

    def test_swapon_read_only_inventory(self):
        for swap in storage.active_swaps():
            self.assertTrue(swap['name'].startswith('/'))
            self.assertGreater(swap['size'], 0)


if __name__ == '__main__':
    unittest.main(argv=[sys.argv[0], *test_args], verbosity=2)
