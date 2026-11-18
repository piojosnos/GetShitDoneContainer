# ------------------------------------------------------------------------------
# Tests of the architecture check
# ------------------------------------------------------------------------------

import platform

from helpers import load_shared_check

architecture = load_shared_check("080_architecture")


# ------------------------------------------------------------------------------
# Architecture
# ------------------------------------------------------------------------------

def test_architecture_passes_with_the_machine_and_its_elf_value():
    result = architecture.architecture_result()

    assert result.passed
    assert result.detail.startswith(f"{platform.machine()}, ELF machine 0x")
