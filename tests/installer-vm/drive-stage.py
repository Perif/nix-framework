"""Drive real interactive installer stages inside a disposable test VM only."""
import sys

import pexpect


stage = sys.argv[1]
child = pexpect.spawn(
    "installer", ["--config", "/root/config", stage], encoding="utf-8", timeout=900
)
child.logfile_read = sys.stdout
if stage == "format":
    child.expect(r"Type exactly: ERASE [^\r\n]+")
    child.sendline("ERASE /dev/disk/by-id/nvme-QEMU_NVMe_Ctrl_INSTALL_TEST")
    child.expect("Type 'yes' to continue, anything else to abort: ")
    child.sendline("yes")
    child.expect(r"Enter password for [^\r\n]+: ")
    child.sendline("disposable-vm-luks-passphrase")
    child.expect(r"Enter password for [^\r\n]+again to be safe: ")
    child.sendline("disposable-vm-luks-passphrase")
elif stage == "recover":
    child.expect(r"Type exactly: RECOVER [^\r\n]+")
    child.sendline("RECOVER /dev/disk/by-id/nvme-QEMU_NVMe_Ctrl_INSTALL_TEST")
    child.expect(r"Enter passphrase for [^\r\n]+: ")
    child.sendline("disposable-vm-luks-passphrase")
elif stage == "account":
    child.expect("New password:")
    child.sendline("Disposable-vm-login-42")
    child.expect("Retype new password:")
    child.sendline("Disposable-vm-login-42")
else:
    raise ValueError(stage)
child.expect(pexpect.EOF)
child.close()
assert child.exitstatus == 0, (child.exitstatus, child.signalstatus)
