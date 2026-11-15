# The primitives of sbx-selfcheck: the result type, the hint builders, the command and
# pin readers, and the result builders both the shared and the agent checks use.
# The image puts it in /usr/local/lib/sbx-selfcheck/.

import os
import platform
import shutil
import stat
import subprocess
from dataclasses import dataclass
from pathlib import Path
from typing import Callable, Mapping

WORKSPACE_DIR = Path("/home/sandbox/workspace")
STATE_DIR = WORKSPACE_DIR / "state"
BUNDLE_DIR = WORKSPACE_DIR / "best-practices"
VERSIONS_FILE = Path("/etc/sbx/versions.env")
MOUNTINFO_FILE = Path("/proc/self/mountinfo")
COMMAND_TIMEOUT_SECONDS = 60
REPORTED_PROBLEM_LIMIT = 10
UNSET_SANDBOX_NAME = "NAME"
ELF_MACHINE_BY_UNAME_MAP = {"aarch64": 0xB7, "x86_64": 0x3E}
HOME_ROOT = "/home"
ELF_HEADER_LENGTH = 20
ELF_MAGIC = b"\x7fELF"
ELF_MACHINE_OFFSET = 18
TOOL_VERSIONS_FILE = Path("/etc/sbx/tool-versions")
HOME_DIR = Path("/home/sandbox")


@dataclass(frozen=True)
class CheckResult:
    passed: bool
    detail: str
    hint: str


@dataclass(frozen=True)
class Check:
    name: str
    function: Callable[[], CheckResult]


def passed(detail: str) -> CheckResult:
    return CheckResult(True, detail, "")


def failed(detail: str, hint: str) -> CheckResult:
    if not hint.strip():
        raise ValueError("a failed check needs a fix hint")

    return CheckResult(False, detail, hint)


def sandbox_name() -> str:
    name = os.environ.get("SBX_NAME", "")

    if not name:
        return UNSET_SANDBOX_NAME

    return name


def mac_hint(action_text: str, command_text: str) -> str:
    return f"{action_text}: on the Mac run: {command_text}"


def rebuild_hint() -> str:
    return mac_hint("rebuild the image and recreate the sandbox", f"sbx-upgrade {sandbox_name()}")


def restart_hint() -> str:
    name = sandbox_name()

    return mac_hint("restart the sandbox", f"sbx-stop {name}, then sbx-start {name}")


def start_hint() -> str:
    name = sandbox_name()

    return mac_hint("run sbx-selfcheck in a sandbox started with sbx-start", f"sbx-start {name}, then sbx-shell {name}")


def shell_hint() -> str:
    return mac_hint("open the sandbox shell with sbx-shell", f"sbx-shell {sandbox_name()}")


def run_command(
    argument_list: list[str],
    environment_map: Mapping[str, str] | None = None,
) -> subprocess.CompletedProcess:
    return subprocess.run(
        argument_list,
        stdin=subprocess.DEVNULL,
        capture_output=True,
        text=True,
        timeout=COMMAND_TIMEOUT_SECONDS,
        check=False,
        env=environment_map,
    )


def parse_versions_text(text: str) -> dict[str, str]:
    value_by_name_map = {}

    for line in text.splitlines():
        stripped_line = line.strip()

        if not stripped_line or stripped_line.startswith("#"):
            continue

        name, separator, value = stripped_line.partition("=")

        if not separator:
            continue

        value_by_name_map[name.strip()] = value.strip()

    return value_by_name_map


def pin_value(name: str, versions_file: Path = VERSIONS_FILE) -> str:
    if not versions_file.is_file():
        return ""

    return parse_versions_text(versions_file.read_text()).get(name, "")


def missing_pin_result(name: str) -> CheckResult:
    return failed(f"{name} is not in {VERSIONS_FILE}", rebuild_hint())


def mount_point_set(mountinfo_text: str) -> set[str]:
    mount_point_found_set = set()

    for line in mountinfo_text.splitlines():
        field_list = line.split()

        if len(field_list) < 5:
            continue

        mount_point_found_set.add(field_list[4])

    return mount_point_found_set


def read_mount_point_set(mountinfo_file: Path = MOUNTINFO_FILE) -> set[str]:
    return mount_point_set(mountinfo_file.read_text())


def root_owned_result(path_mode_list: list[tuple[str, int]]) -> CheckResult:
    problem_list = []

    for path, expected_mode in path_mode_list:
        try:
            path_stat = os.stat(path)
        except FileNotFoundError:
            problem_list.append(f"{path} is missing")
            continue

        actual_mode = stat.S_IMODE(path_stat.st_mode)

        if path_stat.st_uid != 0 or path_stat.st_gid != 0 or actual_mode != expected_mode:
            problem_list.append(
                f"{path} is {path_stat.st_uid}:{path_stat.st_gid} {actual_mode:o}, expected root:root {expected_mode:o}"
            )

    if problem_list:
        return failed("; ".join(problem_list), rebuild_hint())

    return passed(f"{len(path_mode_list)} paths are root-owned with their modes")


def protected_paths_problem_list(path_list: list[Path], mount_point_found_set: set[str]) -> list[str]:
    problem_list = []

    for path in path_list:
        if not os.path.lexists(path):
            problem_list.append(f"{path} is missing")
            continue

        entry_list = [str(path)]

        for current_dir, dir_name_list, file_name_list in os.walk(path, followlinks=False):
            for name in dir_name_list + file_name_list:
                entry_list.append(os.path.join(current_dir, name))

        for entry in entry_list:
            if os.access(entry, os.W_OK):
                problem_list.append(f"{entry} is writable")

        for mount_point in sorted(mount_point_found_set):
            if mount_point == str(path) or mount_point.startswith(str(path) + "/"):
                problem_list.append(f"{mount_point} is a mount point")

    return problem_list


def protected_paths_result(path_list: list[Path], mountinfo_file: Path = MOUNTINFO_FILE) -> CheckResult:
    problem_list = protected_paths_problem_list(path_list, read_mount_point_set(mountinfo_file))

    if problem_list:
        return failed(
            f"{len(problem_list)} problems: " + "; ".join(problem_list[:REPORTED_PROBLEM_LIMIT]),
            rebuild_hint(),
        )

    path_text_list = []

    for path in path_list:
        path_text_list.append(str(path))

    return passed(f"nothing under {', '.join(path_text_list)} is writable or mounted")


def environment_values_result(
    expected_value_by_name_map: Mapping[str, str],
    environment_map: Mapping[str, str] | None = None,
) -> CheckResult:
    if environment_map is None:
        environment_map = os.environ

    problem_list = []
    pair_list = []

    for name, expected_value in expected_value_by_name_map.items():
        if name not in environment_map:
            problem_list.append(f"{name} is not set")
            continue

        actual_value = environment_map[name]

        if actual_value != expected_value:
            problem_list.append(f"{name} is '{actual_value}', expected '{expected_value}'")
            continue

        pair_list.append(f"{name}={actual_value}")

    if problem_list:
        return failed("; ".join(problem_list), "open a fresh shell with sbx-shell; if it stays, " + rebuild_hint())

    return passed(", ".join(pair_list))


def is_under(path_text: str, root_text: str) -> bool:
    return path_text == root_text or path_text.startswith(root_text + "/")


def elf_machine(path: Path) -> int | None:
    with path.open("rb") as binary_file:
        header = binary_file.read(ELF_HEADER_LENGTH)

    if len(header) < ELF_HEADER_LENGTH or not header.startswith(ELF_MAGIC):
        return None

    return int.from_bytes(header[ELF_MACHINE_OFFSET:ELF_MACHINE_OFFSET + 2], "little")


def version_matches(line: str, expected_text: str) -> bool:
    return line == expected_text or line.startswith(expected_text + " ")


def image_tag(image_pin: str) -> str:
    return image_pin.partition("@")[0].rpartition(":")[2]


def jdk_version(temurin_pin: str) -> str:
    return image_tag(temurin_pin).partition("_")[0]


def first_output_line(completed: subprocess.CompletedProcess) -> str:
    for output_text in [completed.stdout, completed.stderr]:
        for line in output_text.splitlines():
            if line.strip():
                return line.strip()

    return ""


def native_machine_problem(real_path: str, command_name: str) -> str:
    expected_machine = ELF_MACHINE_BY_UNAME_MAP.get(platform.machine())
    actual_machine = elf_machine(Path(real_path))

    if expected_machine is None or actual_machine is None or actual_machine == expected_machine:
        return ""

    return f"{command_name} is built for ELF machine 0x{actual_machine:02X}, not {platform.machine()}"


def version_problem(
    command_name: str,
    found_path: str,
    version_argument_list: list[str],
    expected_text: str,
    required_text: str,
    environment_map: Mapping[str, str] | None,
) -> tuple[str, str]:
    completed = run_command([found_path] + version_argument_list, environment_map)
    line = first_output_line(completed)

    if completed.returncode != 0 or not version_matches(line, expected_text):
        return f"{command_name} reports '{line}'; the pin is '{expected_text}'", ""

    if required_text and required_text not in completed.stdout + completed.stderr:
        return f"{command_name} output lacks '{required_text}'", ""

    return "", line


def tool_result(
    command_name: str,
    version_argument_list: list[str] | None = None,
    expected_text: str = "",
    required_text: str = "",
    environment_map: Mapping[str, str] | None = None,
    home_root: str = HOME_ROOT,
) -> CheckResult:
    if environment_map is None:
        environment_map = os.environ

    found_path = shutil.which(command_name, path=environment_map.get("PATH", ""))

    if found_path is None:
        return failed(f"{command_name} is not on PATH", rebuild_hint())

    real_path = os.path.realpath(found_path)

    if is_under(real_path, home_root):
        return failed(
            f"{command_name} resolves to {real_path}, under {home_root}, not the image",
            f"a copy under {home_root} hides the image's {command_name}: remove it, or take its folder off PATH in this sandbox",
        )

    machine_problem = native_machine_problem(real_path, command_name)

    if machine_problem:
        return failed(machine_problem, rebuild_hint())

    if version_argument_list is None:
        return passed(real_path)

    problem, line = version_problem(
        command_name, found_path, version_argument_list, expected_text, required_text, environment_map
    )

    if problem:
        return failed(problem, rebuild_hint())

    return passed(f"{real_path}, {line}")


def expected_base_versions_text(versions_file: Path = VERSIONS_FILE, python_version: str | None = None) -> str:
    if python_version is None:
        python_version = platform.python_version()

    gsd_version = pin_value("GSD_CORE_VERSION", versions_file)
    node_version = pin_value("NODE_VERSION", versions_file)
    temurin_image = pin_value("TEMURIN_IMAGE", versions_file)
    maven_version = pin_value("MAVEN_VERSION", versions_file)

    for name, value in [
        ("GSD_CORE_VERSION", gsd_version),
        ("NODE_VERSION", node_version),
        ("TEMURIN_IMAGE", temurin_image),
        ("MAVEN_VERSION", maven_version),
    ]:
        if not value:
            raise KeyError(name)

    return (
        f"gsd {gsd_version} | node {node_version} | jdk {jdk_version(temurin_image)}"
        f" | mvn {maven_version} | python {python_version}"
    )


def one_line(text: str) -> str:
    return text.replace("\r", " ").replace("\n", " ")
