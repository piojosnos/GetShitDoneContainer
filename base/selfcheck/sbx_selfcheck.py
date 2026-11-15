# ------------------------------------------------------------------------------
# The sbx-selfcheck runner
# ------------------------------------------------------------------------------
# Prints one PASS or FAIL line per check, and a fix line under each FAIL. The
# image puts this file in /usr/local/lib/sbx-selfcheck/.
# ------------------------------------------------------------------------------

import importlib.util
import sys
from pathlib import Path
from types import ModuleType
from typing import TextIO

from selfcheck_core import (
    Check,
    CheckResult,
    failed,
    one_line,
    rebuild_hint,
)


# ------------------------------------------------------------------------------
# Constants
# ------------------------------------------------------------------------------

AGENT_CHECKS_DIR = Path("/etc/sbx/selfcheck.d")
AGENT_CHECKS_CHECK_NAME = "load-agent-checks"
AGENT_MODULE_PREFIX = "sbx_selfcheck_agent_"
FIX_LINE_INDENT = "      "
USAGE_TEXT = "Usage: sbx-selfcheck (no arguments)"


# ------------------------------------------------------------------------------
# Loading the agent checks
# ------------------------------------------------------------------------------

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


# ------------------------------------------------------------------------------
# Running and printing
# ------------------------------------------------------------------------------

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
