# ------------------------------------------------------------------------------
# Tools on PATH
# ------------------------------------------------------------------------------
# A tool must come from the image, not from a copy under /home, must be built for
# the machine it runs on and must report its pinned version. The image puts this
# file in /usr/local/lib/sbx-selfcheck/.
# ------------------------------------------------------------------------------

import os
import platform
import shutil
from pathlib import Path
from typing import Mapping

from check_result import CheckResult, failed, passed
from commands import first_output_line, run_command
from hints import rebuild_hint
from paths import is_under

ELF_MACHINE_BY_UNAME_MAP = {"aarch64": 0xB7, "x86_64": 0x3E}
_HOME_ROOT = "/home"
_ELF_HEADER_LENGTH = 20
_ELF_MAGIC = b"\x7fELF"
_ELF_MACHINE_OFFSET = 18


# ------------------------------------------------------------------------------
# The machine a binary is built for
# ------------------------------------------------------------------------------

def _elf_machine(path: Path) -> int | None:
    with path.open("rb") as binary_file:
        header = binary_file.read(_ELF_HEADER_LENGTH)

    if len(header) < _ELF_HEADER_LENGTH or not header.startswith(_ELF_MAGIC):
        return None

    return int.from_bytes(header[_ELF_MACHINE_OFFSET:_ELF_MACHINE_OFFSET + 2], "little")


def _native_machine_problem(real_path: str, command_name: str) -> str:
    expected_machine = ELF_MACHINE_BY_UNAME_MAP.get(platform.machine())
    actual_machine = _elf_machine(Path(real_path))

    if expected_machine is None or actual_machine is None or actual_machine == expected_machine:
        return ""

    return f"{command_name} is built for ELF machine 0x{actual_machine:02X}, not {platform.machine()}"


# ------------------------------------------------------------------------------
# The version a tool reports
# ------------------------------------------------------------------------------

def _version_matches(line: str, expected_text: str) -> bool:
    return line == expected_text or line.startswith(expected_text + " ")


def _version_problem(
    command_name: str,
    found_path: str,
    version_argument_list: list[str],
    expected_text: str,
    required_text: str,
    environment_map: Mapping[str, str],
) -> tuple[str, str]:
    completed = run_command([found_path] + version_argument_list, environment_map)
    line = first_output_line(completed)

    if completed.returncode != 0 or not _version_matches(line, expected_text):
        return f"{command_name} reports '{line}'; the pin is '{expected_text}'", ""

    if required_text and required_text not in completed.stdout + completed.stderr:
        return f"{command_name} output lacks '{required_text}'", ""

    return "", line


# ------------------------------------------------------------------------------
# The tool result
# ------------------------------------------------------------------------------

def tool_result(
    command_name: str,
    version_argument_list: list[str] | None = None,
    expected_text: str = "",
    required_text: str = "",
    environment_map: Mapping[str, str] = os.environ,
    home_root: str = _HOME_ROOT,
) -> CheckResult:
    found_path = shutil.which(command_name, path=environment_map.get("PATH", ""))

    if found_path is None:
        return failed(f"{command_name} is not on PATH", rebuild_hint())

    real_path = str(Path(found_path).resolve())

    if is_under(real_path, home_root):
        return failed(
            f"{command_name} resolves to {real_path}, under {home_root}, not the image",
            f"a copy under {home_root} hides the image's {command_name}: remove it, or take its folder off PATH in this sandbox",
        )

    machine_problem = _native_machine_problem(real_path, command_name)

    if machine_problem:
        return failed(machine_problem, rebuild_hint())

    if version_argument_list is None:
        return passed(real_path)

    problem, line = _version_problem(
        command_name, found_path, version_argument_list, expected_text, required_text, environment_map
    )

    if problem:
        return failed(problem, rebuild_hint())

    return passed(f"{real_path}, {line}")
