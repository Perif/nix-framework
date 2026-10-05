"""Authenticate using the account created by the real installer account stage."""
import sys

import pexpect

child = pexpect.spawn("login", ["owner"], encoding="utf-8", timeout=60)
child.logfile_read = sys.stdout
child.expect("Password:")
child.sendline("Disposable-vm-login-42")
child.expect(r"owner@installer-target")
child.sendline("printf 'AUTHENTICATED:%s\\n' \"$(id -un)\"")
child.expect("AUTHENTICATED:owner")
child.sendline("exit")
child.expect(pexpect.EOF)
child.close()
assert child.exitstatus == 0
