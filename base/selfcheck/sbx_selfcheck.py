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

from check_result import Check, CheckResult, failed, one_line
from hints import rebuild_hint


# ------------------------------------------------------------------------------
# Constants
# ------------------------------------------------------------------------------

SHARED_CHECKS_DIR = Path(__file__).resolve().parent / "checks"
AGENT_CHECKS_DIR = Path("/etc/sbx/selfcheck.d")
_AGENT_CHECKS_CHECK_NAME = "load-agent-checks"
_CHECK_MODULE_PREFIX = "sbx_selfcheck_check_"
_FIX_LINE_INDENT = "      "
_USAGE_TEXT = "Usage: sbx-selfcheck (no arguments)"


# ------------------------------------------------------------------------------
# Loading the checks
# ------------------------------------------------------------------------------

def load_check_module(module_path: Path) -> ModuleType:
    module_name = _CHECK_MODULE_PREFIX + module_path.stem
    spec = importlib.util.spec_from_file_location(module_name, module_path)

    if spec is None or spec.loader is None:
        raise ImportError(f"cannot load {module_path}")

    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)

    return module


def _load_failure_check(name: str, detail: str) -> Check:
    def report_load_failure() -> CheckResult:
        return failed(detail, rebuild_hint())

    return Check(name, report_load_failure)


def _is_check_list(value: object) -> bool:
    if not isinstance(value, list):
        return False

    for item in value:
        if not isinstance(item, Check):
            return False

    return True


def _module_check_list(module_path: Path) -> list[Check]:
    name = "load-" + module_path.stem.replace("_", "-")

    try:
        module = load_check_module(module_path)
    except Exception as e:
        return [_load_failure_check(name, f"{module_path} did not load: {type(e).__name__}: {e}")]

    if not hasattr(module, "CHECK_LIST"):
        return [_load_failure_check(name, f"{module_path} defines no CHECK_LIST")]

    check_list = module.CHECK_LIST

    if not _is_check_list(check_list):
        return [_load_failure_check(name, f"{module_path} defines a CHECK_LIST that is not a list of checks")]

    return list(check_list)


def dir_check_list(checks_dir: Path) -> list[Check]:
    check_list = []

    for module_path in sorted(checks_dir.glob("*.py")):
        check_list.extend(_module_check_list(module_path))

    return check_list


def collect_agent_checks(agent_checks_dir: Path) -> list[Check]:
    agent_check_list = dir_check_list(agent_checks_dir)

    if agent_check_list:
        return agent_check_list

    return [
        _load_failure_check(
            _AGENT_CHECKS_CHECK_NAME,
            f"found no agent checks in {agent_checks_dir}, so the image's own checks did not run",
        )
    ]


def collect_checks(shared_checks_dir: Path, agent_checks_dir: Path) -> list[Check]:
    return dir_check_list(shared_checks_dir) + collect_agent_checks(agent_checks_dir)


# ------------------------------------------------------------------------------
# Running and printing
# ------------------------------------------------------------------------------

def _run_check(check: Check) -> CheckResult:
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


def _outcome_lines(name: str, result: CheckResult) -> list[str]:
    detail = one_line(result.detail)

    if result.passed:
        return [f"PASS: {name}: {detail}"]

    return [f"FAIL: {name}: {detail}", f"{_FIX_LINE_INDENT}fix: {one_line(result.hint)}"]


def _write_outcome(output: TextIO, name: str, result: CheckResult) -> None:
    for line in _outcome_lines(name, result):
        output.write(line + "\n")

    output.flush()


def _run_all_checks(check_list: list[Check], output: TextIO) -> int:
    failed_count = 0

    for check in check_list:
        result = _run_check(check)

        if not result.passed:
            failed_count += 1

        _write_outcome(output, check.name, result)

    return failed_count


def _write_summary(output: TextIO, check_count: int, failed_count: int) -> None:
    output.write(f"sbx-selfcheck: {check_count} checks, {failed_count} failed\n")
    output.flush()


def report_checks(check_list: list[Check], output: TextIO) -> int:
    failed_count = _run_all_checks(check_list, output)

    _write_summary(output, len(check_list), failed_count)

    if failed_count > 0:
        return 1

    return 0


def run_selfcheck(shared_checks_dir: Path, agent_checks_dir: Path, output: TextIO) -> int:
    return report_checks(collect_checks(shared_checks_dir, agent_checks_dir), output)


def main(argument_list: list[str], shared_checks_dir: Path, agent_checks_dir: Path) -> int:
    if argument_list:
        print(_USAGE_TEXT, file=sys.stderr)

        return 2

    return run_selfcheck(shared_checks_dir, agent_checks_dir, sys.stdout)
