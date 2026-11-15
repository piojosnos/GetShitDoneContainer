# The sbx-selfcheck library: the result type, the hint builders and the runner.
# The image puts it in /usr/local/lib/sbx-selfcheck/, next to the launcher and
# the shared checks. Every check returns one result; the runner prints one PASS
# or FAIL line per check, and a fix line right under each FAIL.

import importlib.util
import os
import platform
import shutil
import stat
import subprocess
import sys
from dataclasses import dataclass
from pathlib import Path
from types import ModuleType
from typing import Callable, Mapping, TextIO

WORKSPACE_DIR = Path("/home/sandbox/workspace")
STATE_DIR = WORKSPACE_DIR / "state"
BUNDLE_DIR = WORKSPACE_DIR / "best-practices"
VERSIONS_FILE = Path("/etc/sbx/versions.env")
MOUNTINFO_FILE = Path("/proc/self/mountinfo")
COMMAND_TIMEOUT_SECONDS = 60
REPORTED_PROBLEM_LIMIT = 10
AGENT_CHECKS_DIR = Path("/etc/sbx/selfcheck.d")
AGENT_CHECKS_CHECK_NAME = "load-agent-checks"
AGENT_MODULE_PREFIX = "sbx_selfcheck_agent_"
FIX_LINE_INDENT = "      "
UNSET_SANDBOX_NAME = "NAME"
USAGE_TEXT = "Usage: sbx-selfcheck (no arguments)"
ELF_MACHINE_BY_UNAME_MAP = {"aarch64": 0xB7, "x86_64": 0x3E}
HOME_ROOT = "/home"
ELF_HEADER_LENGTH = 20
ELF_MAGIC = b"\x7fELF"
ELF_MACHINE_OFFSET = 18
TOOL_VERSIONS_FILE = Path("/etc/sbx/tool-versions")
RULES_LINK_TEXT = "../../best-practices/rules"
SKILL_LINK_TEXT_TEMPLATE = "../../../best-practices/skills/{name}"
BUNDLE_SKILL_LIST_NAME = ".best-practices-skills"


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


def versions_line_result(
    prefix_text: str,
    versions_line_file: Path = TOOL_VERSIONS_FILE,
    versions_file: Path = VERSIONS_FILE,
) -> CheckResult:
    try:
        expected_line = prefix_text + expected_base_versions_text(versions_file)
    except KeyError as e:
        return missing_pin_result(e.args[0])

    if not versions_line_file.is_file():
        return failed(f"{versions_line_file} is missing", rebuild_hint())

    actual_text = versions_line_file.read_text()

    if actual_text != expected_line + "\n":
        return failed(
            f"{versions_line_file} holds '{one_line(actual_text.rstrip())}'; expected '{expected_line}'",
            rebuild_hint(),
        )

    return passed(f"the line is {expected_line}")


def login_file_result(login_file: Path, login_hint: str) -> CheckResult:
    if not login_file.is_file() or login_file.stat().st_size == 0:
        return failed(f"{login_file} is missing or empty", login_hint)

    return passed(f"{login_file} is there ({login_file.stat().st_size} bytes)")


def gsd_synced_result(config_dir: Path, versions_file: Path = VERSIONS_FILE) -> CheckResult:
    pinned_version = pin_value("GSD_CORE_VERSION", versions_file)

    if not pinned_version:
        return missing_pin_result("GSD_CORE_VERSION")

    version_file = config_dir / "gsd-core" / "VERSION"
    hint = restart_hint() + "; the start syncs GSD"

    if not version_file.is_file():
        return failed(f"{version_file} is missing; the image has '{pinned_version}'", hint)

    synced_version = version_file.read_text().strip()

    if synced_version != pinned_version:
        return failed(f"GSD in {config_dir} is '{synced_version}'; the image has '{pinned_version}'", hint)

    return passed(f"GSD {pinned_version} in {config_dir}")


def bundle_skill_name_list(bundle_dir: Path) -> list[str]:
    skills_dir = bundle_dir / "skills"
    skill_name_list = []

    if not skills_dir.is_dir():
        return skill_name_list

    for skill_dir in sorted(skills_dir.iterdir()):
        if skill_dir.is_dir() and not skill_dir.name.startswith("."):
            skill_name_list.append(skill_dir.name)

    return skill_name_list


def link_text(link: Path) -> str | None:
    try:
        return os.readlink(link)
    except OSError:
        return None


def rules_link_problem(config_dir: Path, bundle_dir: Path) -> str:
    rules_link = config_dir / "rules"
    actual_text = link_text(rules_link)

    if actual_text is None:
        return f"{rules_link} is not a link"

    if actual_text != RULES_LINK_TEXT:
        return f"{rules_link} links to '{actual_text}', expected '{RULES_LINK_TEXT}'"

    try:
        same_folder = os.path.samefile(rules_link, bundle_dir / "rules")
    except OSError:
        same_folder = False

    if not same_folder:
        return f"{rules_link} does not reach {bundle_dir / 'rules'}"

    return ""


def skill_link_problem_list(config_dir: Path, skill_name_list: list[str]) -> list[str]:
    problem_list = []

    for skill_name in skill_name_list:
        skill_link = config_dir / "skills" / skill_name
        expected_text = SKILL_LINK_TEXT_TEMPLATE.format(name=skill_name)
        actual_text = link_text(skill_link)

        if actual_text is None:
            problem_list.append(f"{skill_link} is not a link")
        elif actual_text != expected_text:
            problem_list.append(f"{skill_link} links to '{actual_text}', expected '{expected_text}'")

    return problem_list


def skill_list_problem_list(config_dir: Path, skill_name_list: list[str]) -> list[str]:
    list_file = config_dir / BUNDLE_SKILL_LIST_NAME

    if not list_file.is_file():
        return [f"{list_file} is missing"]

    listed_name_set = set()

    for line in list_file.read_text().splitlines():
        if line.strip():
            listed_name_set.add(line.strip())

    problem_list = []

    for skill_name in skill_name_list:
        if skill_name not in listed_name_set:
            problem_list.append(f"{list_file} does not list {skill_name}")

    for listed_name in sorted(listed_name_set - set(skill_name_list)):
        problem_list.append(f"{list_file} lists {listed_name}, which the clone does not have")

    return problem_list


def bundle_links_result(config_dir: Path, bundle_dir: Path, links_rules: bool) -> CheckResult:
    hint = (
        "link the clone in this sandbox: run sbx-gh-login and sbx-bundle-clone when there is no clone, "
        "else /etc/sbx/start.d/10-best-practices"
    )
    needed_dir = bundle_dir / "rules" if links_rules else bundle_dir / "skills"

    if not needed_dir.is_dir():
        return failed(f"no clone at {bundle_dir}", hint)

    skill_name_list = bundle_skill_name_list(bundle_dir)
    problem_list = []

    if links_rules:
        rules_problem = rules_link_problem(config_dir, bundle_dir)

        if rules_problem:
            problem_list.append(rules_problem)

    problem_list.extend(skill_link_problem_list(config_dir, skill_name_list))
    problem_list.extend(skill_list_problem_list(config_dir, skill_name_list))

    if problem_list:
        return failed("; ".join(problem_list), hint)

    detail = f"{len(skill_name_list)} skills linked from {bundle_dir}"

    if links_rules:
        detail += ", rules linked"

    return passed(detail)


def home_links_result(link_target_list: list[tuple[Path, Path]]) -> CheckResult:
    problem_list = []
    pair_list = []

    for link, target in link_target_list:
        actual_text = link_text(link)

        if actual_text is None:
            problem_list.append(f"{link} is not a link")
        elif actual_text != str(target):
            problem_list.append(f"{link} links to '{actual_text}', expected '{target}'")
        else:
            pair_list.append(f"{link} -> {target}")

    if problem_list:
        return failed("; ".join(problem_list), rebuild_hint())

    return passed(", ".join(pair_list))


def history_free_environment(environment_map: Mapping[str, str] | None = None) -> dict[str, str]:
    if environment_map is None:
        environment_map = os.environ

    history_free_environment_map = dict(environment_map)
    history_free_environment_map["HISTFILE"] = "/dev/null"

    return history_free_environment_map


def load_check_module(module_path: Path) -> ModuleType:
    module_name = AGENT_MODULE_PREFIX + module_path.stem
    spec = importlib.util.spec_from_file_location(module_name, module_path)

    if spec is None or spec.loader is None:
        raise ImportError(f"cannot load {module_path}")

    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)

    return module


def load_failure_check(name: str, detail: str) -> Check:
    def report_load_failure() -> CheckResult:
        return failed(detail, rebuild_hint())

    return Check(name, report_load_failure)


def is_check_list(value: object) -> bool:
    if not isinstance(value, list):
        return False

    for item in value:
        if not isinstance(item, Check):
            return False

    return True


def module_check_list(module_path: Path) -> list[Check]:
    name = "load-" + module_path.stem

    try:
        module = load_check_module(module_path)
    except Exception as e:
        return [load_failure_check(name, f"{module_path} did not load: {type(e).__name__}: {e}")]

    if not hasattr(module, "CHECK_LIST"):
        return [load_failure_check(name, f"{module_path} defines no CHECK_LIST")]

    check_list = module.CHECK_LIST

    if not is_check_list(check_list):
        return [load_failure_check(name, f"{module_path} defines a CHECK_LIST that is not a list of checks")]

    return list(check_list)


def collect_checks(shared_check_list: list[Check], checks_dir: Path) -> list[Check]:
    check_list = list(shared_check_list)

    for module_path in sorted(checks_dir.glob("*.py")):
        check_list.extend(module_check_list(module_path))

    if len(check_list) == len(shared_check_list):
        check_list.append(
            load_failure_check(
                AGENT_CHECKS_CHECK_NAME,
                f"found no agent checks in {checks_dir}, so the image's own checks did not run",
            )
        )

    return check_list


def run_check(check: Check) -> CheckResult:
    try:
        result = check.function()
    except Exception as e:
        return failed(
            f"raised {type(e).__name__}: {e}",
            "this is a bug in the self-check or a broken image; " + rebuild_hint(),
        )

    if not isinstance(result, CheckResult):
        return failed(
            f"returned {type(result).__name__} instead of a CheckResult",
            "this is a bug in the self-check or a broken image; " + rebuild_hint(),
        )

    return result


def one_line(text: str) -> str:
    return text.replace("\r", " ").replace("\n", " ")


def outcome_lines(name: str, result: CheckResult) -> list[str]:
    detail = one_line(result.detail)

    if result.passed:
        return [f"PASS: {name}: {detail}"]

    return [f"FAIL: {name}: {detail}", f"{FIX_LINE_INDENT}fix: {one_line(result.hint)}"]


def run_selfcheck(shared_check_list: list[Check], checks_dir: Path, output: TextIO) -> int:
    check_list = collect_checks(shared_check_list, checks_dir)
    failed_count = 0

    for check in check_list:
        result = run_check(check)

        if not result.passed:
            failed_count += 1

        for line in outcome_lines(check.name, result):
            output.write(line + "\n")

        output.flush()

    output.write(f"sbx-selfcheck: {len(check_list)} checks, {failed_count} failed\n")
    output.flush()

    if failed_count > 0:
        return 1

    return 0


def main(argument_list: list[str], shared_check_list: list[Check], checks_dir: Path) -> int:
    if argument_list:
        print(USAGE_TEXT, file=sys.stderr)

        return 2

    return run_selfcheck(shared_check_list, checks_dir, sys.stdout)
