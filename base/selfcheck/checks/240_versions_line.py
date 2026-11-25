# --------------------------------------------------------------------------------
# Checks: the versions line a shell prints
# --------------------------------------------------------------------------------
# The image puts this file in /usr/local/lib/sbx-selfcheck/checks/.
# --------------------------------------------------------------------------------

import os
from pathlib import Path
from typing import Mapping

from check_result import Check, CheckResult, failed, passed, problem_list_result
from commands import first_output_line, run_command
from hints import rebuild_hint
from paths import TOOL_VERSIONS_FILE, VERSIONS_FILE
from pins import missing_pin_result
from versions_text import expected_base_versions_text

_QUIET_SHELL_FLAG_LIST = ["-c", "-lc"]
_FIRST_LINES_LIMIT = 3


# --------------------------------------------------------------------------------
# Versions line text
# --------------------------------------------------------------------------------

def _first_lines(text: str) -> str:
    line_list = []

    for line in text.splitlines():
        if line.strip():
            line_list.append(line.strip())

    return " / ".join(line_list[:_FIRST_LINES_LIMIT])


# --------------------------------------------------------------------------------

def versions_record_result(versions_file: Path = VERSIONS_FILE) -> CheckResult:
    if not versions_file.is_file():
        return failed(f"{versions_file} is missing", rebuild_hint())

    value_by_name_map = parse_versions_text(versions_file.read_text())
    missing_list = []

    for name in _SHARED_PIN_NAME_LIST:
        if not value_by_name_map.get(name):
            missing_list.append(name)

    if missing_list:
        return failed(f"{', '.join(missing_list)} missing or empty in {versions_file}", rebuild_hint())

    return passed(f"{len(value_by_name_map)} pins in {versions_file}")


# --------------------------------------------------------------------------------
# Versions line file
# --------------------------------------------------------------------------------

def versions_line_file_result(
    versions_line_file: Path = TOOL_VERSIONS_FILE,
    versions_file: Path = VERSIONS_FILE,
) -> CheckResult:
    try:
        base_text = expected_base_versions_text(versions_file)
    except KeyError as e:
        return missing_pin_result(e.args[0])

    if not versions_line_file.is_file():
        return failed(f"{versions_line_file} is missing", rebuild_hint())

    actual_text = versions_line_file.read_text()
    one_line_text = actual_text.rstrip("\n")

    if actual_text.endswith("\n") and "\n" not in one_line_text and (
        one_line_text == base_text or one_line_text.endswith(" | " + base_text)
    ):
        return passed(f"the line ends with {base_text}")

    return failed(
        f"{versions_line_file} holds '{_first_lines(actual_text)}'; expected one line ending with '{base_text}'",
        rebuild_hint(),
    )


# --------------------------------------------------------------------------------
# Versions line of an interactive shell
# --------------------------------------------------------------------------------

def _history_free_environment(environment_map: Mapping[str, str] = os.environ) -> dict[str, str]:
    history_free_environment_map = dict(environment_map)
    history_free_environment_map["HISTFILE"] = "/dev/null"

    return history_free_environment_map


# --------------------------------------------------------------------------------

def interactive_versions_line_result(
    versions_line_file: Path = TOOL_VERSIONS_FILE,
    environment_map: Mapping[str, str] = os.environ,
) -> CheckResult:
    if not versions_line_file.is_file():
        return failed(f"{versions_line_file} is missing", rebuild_hint())

    expected_text = versions_line_file.read_text()
    completed = run_command(["bash", "-i"], _history_free_environment(environment_map))

    if completed.stdout != expected_text:
        return failed(
            f"an interactive shell printed '{_first_lines(completed.stdout)}'; expected the versions line once",
            rebuild_hint(),
        )

    return passed(f"an interactive shell prints {versions_line_file} once")


# --------------------------------------------------------------------------------
# Versions line of a quiet shell
# --------------------------------------------------------------------------------

def quiet_shells_result(environment_map: Mapping[str, str] = os.environ) -> CheckResult:
    problem_list = []

    for flag in _QUIET_SHELL_FLAG_LIST:
        completed = run_command(["bash", flag, "true"], environment_map)

        if completed.stdout or completed.stderr:
            problem_list.append(f"bash {flag} true printed '{first_output_line(completed)}'")

    return problem_list_result(problem_list, rebuild_hint(), "bash -c true and bash -lc true print nothing")

# --------------------------------------------------------------------------------
# Check entries
# --------------------------------------------------------------------------------

def _check_versions_line_file() -> CheckResult:
    return versions_line_file_result()


# --------------------------------------------------------------------------------

def _check_versions_line_interactive() -> CheckResult:
    return interactive_versions_line_result()


# --------------------------------------------------------------------------------

def _check_versions_line_quiet() -> CheckResult:
    return quiet_shells_result()


CHECK_LIST = [
    Check("versions-line-file", _check_versions_line_file),
    Check("versions-line-interactive", _check_versions_line_interactive),
    Check("versions-line-quiet", _check_versions_line_quiet),
]
