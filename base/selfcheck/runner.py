# ------------------------------------------------------------------------------
# The sbx-selfcheck runner: loads the check files, runs them and prints
# ------------------------------------------------------------------------------
# Prints one PASS or FAIL line per check, and a fix line under each FAIL. The
# image puts this file in /usr/local/lib/sbx-selfcheck/.
# ------------------------------------------------------------------------------

import sys
from pathlib import Path
from types import ModuleType
from typing import TextIO

from check_result import Check
from step_files import StepFileKind, load_failure_check, load_list, load_module, run_one, write_outcome


# ------------------------------------------------------------------------------
# Constants
# ------------------------------------------------------------------------------

SHARED_CHECKS_DIR = Path(__file__).resolve().parent / "checks"
AGENT_CHECKS_DIR = Path("/etc/sbx/selfcheck.d")
_AGENT_CHECKS_CHECK_NAME = "load-agent-checks"
_FILE_KIND = StepFileKind(
    list_name="CHECK_LIST",
    item_word="checks",
    module_prefix="sbx_selfcheck_check_",
    owner_text="sbx-selfcheck",
    pass_word="PASS",
)
_USAGE_TEXT = "Usage: sbx-selfcheck (no arguments)"


# ------------------------------------------------------------------------------
# Loading the checks
# ------------------------------------------------------------------------------

def load_check_module(module_path: Path) -> ModuleType:
    return load_module(module_path, _FILE_KIND.module_prefix)


def dir_check_list(checks_dir: Path) -> list[Check]:
    check_list = []

    for module_path in sorted(checks_dir.glob("*.py")):
        check_list.extend(load_list(module_path, _FILE_KIND))

    return check_list


def collect_agent_checks(agent_checks_dir: Path) -> list[Check]:
    agent_check_list = []

    if agent_checks_dir.is_dir():
        for agent_dir in sorted(agent_checks_dir.iterdir()):
            if agent_dir.is_dir():
                agent_check_list.extend(dir_check_list(agent_dir))

    if agent_check_list:
        return agent_check_list

    return [
        load_failure_check(
            _AGENT_CHECKS_CHECK_NAME,
            f"found no agent checks in {agent_checks_dir}, so the image's own checks did not run",
        )
    ]


def collect_checks(shared_checks_dir: Path, agent_checks_dir: Path) -> list[Check]:
    return dir_check_list(shared_checks_dir) + collect_agent_checks(agent_checks_dir)


# ------------------------------------------------------------------------------
# Running and printing
# ------------------------------------------------------------------------------

def _run_all_checks(check_list: list[Check], output: TextIO) -> int:
    failed_count = 0

    for check in check_list:
        result = run_one(check, _FILE_KIND)

        if not result.passed:
            failed_count += 1

        write_outcome(check.name, result, _FILE_KIND, output)

    return failed_count


def _write_summary(check_count: int, failed_count: int, output: TextIO) -> None:
    output.write(f"sbx-selfcheck: {check_count} checks, {failed_count} failed\n")
    output.flush()


def report_checks(check_list: list[Check], output: TextIO) -> int:
    failed_count = _run_all_checks(check_list, output)

    _write_summary(len(check_list), failed_count, output)

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
