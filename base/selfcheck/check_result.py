# ------------------------------------------------------------------------------
# The result of a check
# ------------------------------------------------------------------------------
# The types and builders every check file and the runner share. The image puts
# this file in /usr/local/lib/sbx-selfcheck/.
# ------------------------------------------------------------------------------

from dataclasses import dataclass
from typing import Callable


# ------------------------------------------------------------------------------
# Check and result types
# ------------------------------------------------------------------------------

@dataclass(frozen=True)
class CheckResult:
    passed: bool
    detail: str
    hint: str


@dataclass(frozen=True)
class Check:
    name: str
    function: Callable[[], CheckResult]


# ------------------------------------------------------------------------------
# Result builders
# ------------------------------------------------------------------------------

def passed(detail: str) -> CheckResult:
    return CheckResult(True, detail, "")


def failed(detail: str, hint: str) -> CheckResult:
    if not hint.strip():
        raise ValueError("a failed check needs a fix hint")

    return CheckResult(False, detail, hint)


def problem_list_result(problem_list: list[str], hint: str, passed_detail: str) -> CheckResult:
    if problem_list:
        return failed("; ".join(problem_list), hint)

    return passed(passed_detail)


def one_line(text: str) -> str:
    return text.replace("\r", " ").replace("\n", " ")
