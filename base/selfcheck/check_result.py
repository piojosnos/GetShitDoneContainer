# --------------------------------------------------------------------------------
# The result of a check
# --------------------------------------------------------------------------------
# The types and builders every check file and the runner share. The image puts
# this file in /usr/local/lib/sbx-selfcheck/.
# --------------------------------------------------------------------------------

from dataclasses import dataclass
from pathlib import Path
from typing import Callable

from hints import state_writable_hint

_LIST_LIMIT = 10


# --------------------------------------------------------------------------------
# Check and result types
# --------------------------------------------------------------------------------

@dataclass(frozen=True)
class CheckResult:
    passed: bool
    detail: str
    hint: str


@dataclass(frozen=True)
class Check:
    name: str
    function: Callable[[], CheckResult]


# --------------------------------------------------------------------------------
# Result builders
# --------------------------------------------------------------------------------

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


def capped_list_text(item_list: list[str], separator: str, limit: int = _LIST_LIMIT) -> str:
    return separator.join(item_list[:limit])


def capped_problem_detail(problem_list: list[str], limit: int = _LIST_LIMIT) -> str:
    return f"{len(problem_list)} problems: " + capped_list_text(problem_list, "; ", limit)


def one_line(text: str) -> str:
    return text.replace("\r", " ").replace("\n", " ")


# --------------------------------------------------------------------------------
# Making a state directory
# --------------------------------------------------------------------------------

def make_state_dir(dir_path: Path) -> CheckResult | None:
    try:
        dir_path.mkdir(parents=True, exist_ok=True)
    except OSError as e:
        return failed(f"cannot make {dir_path}: {e.strerror}", state_writable_hint())

    return None
