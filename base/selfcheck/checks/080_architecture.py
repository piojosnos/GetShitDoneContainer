# --------------------------------------------------------------------------------
# Check: the machine is one the images are built for
# --------------------------------------------------------------------------------
# The image puts this file in /usr/local/lib/sbx-selfcheck/checks/.
# --------------------------------------------------------------------------------

import platform

from check_result import Check, CheckResult, failed, passed
from hints import rebuild_hint
from tools import ELF_MACHINE_BY_UNAME_MAP


# --------------------------------------------------------------------------------
# Architecture
# --------------------------------------------------------------------------------

def architecture_result() -> CheckResult:
    machine = platform.machine()

    if machine not in ELF_MACHINE_BY_UNAME_MAP:
        return failed(f"the machine is {machine}; the images are built for aarch64 or x86_64", rebuild_hint())

    return passed(f"{machine}, ELF machine 0x{ELF_MACHINE_BY_UNAME_MAP[machine]:02X}")


# --------------------------------------------------------------------------------
# Check entries
# --------------------------------------------------------------------------------

def _check_architecture() -> CheckResult:
    return architecture_result()


CHECK_LIST = [Check("architecture", _check_architecture)]
