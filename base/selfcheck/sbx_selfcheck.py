# The sbx-selfcheck library: the result type, the hint builders and the runner.
# The image puts it in /usr/local/lib/sbx-selfcheck/, next to the launcher and
# the shared checks. Every check returns one result; the runner prints one PASS
# or FAIL line per check, and a fix line right under each FAIL.

import importlib.util
import os
import subprocess
import sys
from dataclasses import dataclass
from pathlib import Path
from typing import Callable, Mapping, TextIO

WORKSPACE_DIR = Path("/home/sandbox/workspace")
STATE_DIR = WORKSPACE_DIR / "state"
BUNDLE_DIR = WORKSPACE_DIR / "best-practices"
VERSIONS_FILE = Path("/etc/sbx/versions.env")
MOUNTINFO_FILE = Path("/proc/self/mountinfo")
COMMAND_TIMEOUT_SECONDS = 60
AGENT_CHECKS_DIR = Path("/etc/sbx/selfcheck.d")
AGENT_MODULE_PREFIX = "sbx_selfcheck_agent_"
FIX_LINE_INDENT = "      "
UNSET_SANDBOX_NAME = "NAME"
USAGE_TEXT = "Usage: sbx-selfcheck (no arguments)"


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
    environment: Mapping[str, str] | None = None,
) -> subprocess.CompletedProcess:
    return subprocess.run(
        argument_list,
        stdin=subprocess.DEVNULL,
        capture_output=True,
        text=True,
        timeout=COMMAND_TIMEOUT_SECONDS,
        check=False,
        env=environment,
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
    mount_point_collection = set()

    for line in mountinfo_text.splitlines():
        field_list = line.split()

        if len(field_list) < 5:
            continue

        mount_point_collection.add(field_list[4])

    return mount_point_collection


def read_mount_point_set(mountinfo_file: Path = MOUNTINFO_FILE) -> set[str]:
    return mount_point_set(mountinfo_file.read_text())


def environment_values_result(
    expected_value_by_name_map: Mapping[str, str],
    environment: Mapping[str, str] | None = None,
) -> CheckResult:
    if environment is None:
        environment = os.environ

    problem_list = []
    pair_list = []

    for name, expected_value in expected_value_by_name_map.items():
        if name not in environment:
            problem_list.append(f"{name} is not set")
            continue

        actual_value = environment[name]

        if actual_value != expected_value:
            problem_list.append(f"{name} is '{actual_value}', expected '{expected_value}'")
            continue

        pair_list.append(f"{name}={actual_value}")

    if problem_list:
        return failed("; ".join(problem_list), "open a fresh shell with sbx-shell; if it stays, " + rebuild_hint())

    return passed(", ".join(pair_list))


def load_check_module(module_path: Path):
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


def module_check_list(module_path: Path) -> list[Check]:
    name = "load-" + module_path.stem

    try:
        module = load_check_module(module_path)
    except Exception as error:
        return [load_failure_check(name, f"{module_path} did not load: {type(error).__name__}: {error}")]

    if not hasattr(module, "CHECK_LIST"):
        return [load_failure_check(name, f"{module_path} defines no CHECK_LIST")]

    return list(module.CHECK_LIST)


def collect_checks(shared_check_list: list[Check], checks_dir: Path) -> list[Check]:
    check_list = list(shared_check_list)

    for module_path in sorted(checks_dir.glob("*.py")):
        check_list.extend(module_check_list(module_path))

    return check_list


def run_check(check: Check) -> CheckResult:
    try:
        return check.function()
    except Exception as error:
        return failed(
            f"raised {type(error).__name__}: {error}",
            "this is a bug in the self-check or a broken image; " + rebuild_hint(),
        )


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
