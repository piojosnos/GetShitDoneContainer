# ------------------------------------------------------------------------------
# Step files: load a numbered file's list, run one entry and print its lines
# ------------------------------------------------------------------------------
# sbx-init and sbx-selfcheck share this code; a StepFileKind holds the words that
# differ between them. The image puts this file in /usr/local/lib/sbx-selfcheck/.
# ------------------------------------------------------------------------------

import importlib.util
from dataclasses import dataclass
from pathlib import Path
from types import ModuleType
from typing import TextIO

from check_result import Check, CheckResult, failed, one_line
from hints import rebuild_hint

_FIX_LINE_INDENT = "      "


# ------------------------------------------------------------------------------
# What differs between the runners
# ------------------------------------------------------------------------------

@dataclass(frozen=True)
class StepFileKind:
    list_name: str
    item_word: str
    module_prefix: str
    owner_text: str
    pass_word: str


# ------------------------------------------------------------------------------
# Loading a step file
# ------------------------------------------------------------------------------

def load_module(module_path: Path, module_prefix: str) -> ModuleType:
    module_name = module_prefix + module_path.parent.name + "_" + module_path.stem
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


def _is_check_list(value: object) -> bool:
    if not isinstance(value, list):
        return False

    for item in value:
        if not isinstance(item, Check):
            return False

    return True


def load_list(module_path: Path, kind: StepFileKind) -> list[Check]:
    name = "load-" + module_path.parent.name + "-" + module_path.stem.replace("_", "-")

    try:
        module = load_module(module_path, kind.module_prefix)
    except Exception as e:
        return [load_failure_check(name, f"{module_path} did not load: {type(e).__name__}: {e}")]

    if not hasattr(module, kind.list_name):
        return [load_failure_check(name, f"{module_path} defines no {kind.list_name}")]

    check_list = getattr(module, kind.list_name)

    if not _is_check_list(check_list):
        return [
            load_failure_check(
                name,
                f"{module_path} defines a {kind.list_name} that is not a list of {kind.item_word}",
            )
        ]

    return list(check_list)


# ------------------------------------------------------------------------------
# Running one entry and printing it
# ------------------------------------------------------------------------------

def run_one(check: Check, kind: StepFileKind) -> CheckResult:
    bug_hint = "this is a bug in " + kind.owner_text + " or a broken image; " + rebuild_hint()

    try:
        result = check.function()
    except Exception as e:
        return failed(f"raised {type(e).__name__}: {e}", bug_hint)

    if not isinstance(result, CheckResult):
        return failed(f"returned {type(result).__name__} instead of a CheckResult", bug_hint)

    return result


def outcome_lines(name: str, result: CheckResult, kind: StepFileKind) -> list[str]:
    detail = one_line(result.detail)

    if result.passed:
        return [f"{kind.pass_word}: {name}: {detail}"]

    return [f"FAIL: {name}: {detail}", f"{_FIX_LINE_INDENT}fix: {one_line(result.hint)}"]


def write_outcome(output: TextIO, name: str, result: CheckResult, kind: StepFileKind) -> None:
    for line in outcome_lines(name, result, kind):
        output.write(line + "\n")

    output.flush()
