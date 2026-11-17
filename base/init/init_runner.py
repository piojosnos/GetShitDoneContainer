# ------------------------------------------------------------------------------
# The sbx-init runner: loads the step files, runs them in order and prints
# ------------------------------------------------------------------------------
# Prints one OK or FAIL line per step, and a fix line under each FAIL. The image
# puts this file in /usr/local/lib/sbx-init/.
# ------------------------------------------------------------------------------

import fcntl
import importlib.util
import signal
import sys
from pathlib import Path
from types import ModuleType
from typing import TextIO

import paths
from check_result import Check, CheckResult, failed, one_line
from hints import rebuild_hint


# ------------------------------------------------------------------------------
# Constants
# ------------------------------------------------------------------------------

SHARED_STEPS_DIR = Path(__file__).resolve().parent / "steps"
_STEP_MODULE_PREFIX = "sbx_init_step_"
_FIX_LINE_INDENT = "      "
_USAGE_TEXT = "Usage: sbx-init (no arguments)"
_LOCK_STEP_NAME = "lock"
_MARKER_STEP_NAME = "marker"
_AGENT_STEPS_STEP_NAME = "load-agent-steps"
_SHARED_GROUP = 0
_AGENT_GROUP = 1
_INTERRUPTED_EXIT_CODE = 130
_INTERRUPTED_TEXT = "sbx-init: interrupted; run sbx-init again"
_STOP_SIGNAL_LIST = [signal.SIGHUP, signal.SIGTERM]


# ------------------------------------------------------------------------------
# Loading the steps
# ------------------------------------------------------------------------------

def load_step_module(module_path: Path) -> ModuleType:
    module_name = _STEP_MODULE_PREFIX + module_path.parent.name + "_" + module_path.stem
    spec = importlib.util.spec_from_file_location(module_name, module_path)

    if spec is None or spec.loader is None:
        raise ImportError(f"cannot load {module_path}")

    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)

    return module


def _load_failure_step(name: str, detail: str) -> Check:
    def report_load_failure() -> CheckResult:
        return failed(detail, rebuild_hint())

    return Check(name, report_load_failure)


def _is_step_list(value: object) -> bool:
    if not isinstance(value, list):
        return False

    for item in value:
        if not isinstance(item, Check):
            return False

    return True


def _module_step_list(module_path: Path) -> list[Check]:
    name = "load-" + module_path.parent.name + "-" + module_path.stem.replace("_", "-")

    try:
        module = load_step_module(module_path)
    except Exception as e:
        return [_load_failure_step(name, f"{module_path} did not load: {type(e).__name__}: {e}")]

    if not hasattr(module, "STEP_LIST"):
        return [_load_failure_step(name, f"{module_path} defines no STEP_LIST")]

    step_list = module.STEP_LIST

    if not _is_step_list(step_list):
        return [_load_failure_step(name, f"{module_path} defines a STEP_LIST that is not a list of steps")]

    return list(step_list)


def _step_file_list(shared_steps_dir: Path, agent_steps_dir: Path) -> list[tuple[str, int, Path]]:
    step_file_list = []

    for module_path in shared_steps_dir.glob("*.py"):
        step_file_list.append((module_path.name, _SHARED_GROUP, module_path))

    if agent_steps_dir.is_dir():
        for agent_dir in sorted(agent_steps_dir.iterdir()):
            if not agent_dir.is_dir():
                continue

            for module_path in agent_dir.glob("*.py"):
                step_file_list.append((module_path.name, _AGENT_GROUP, module_path))

    return step_file_list


def _has_agent_file(step_file_list: list[tuple[str, int, Path]]) -> bool:
    for _, group, _ in step_file_list:
        if group == _AGENT_GROUP:
            return True

    return False


def collect_steps(shared_steps_dir: Path, agent_steps_dir: Path) -> list[Check]:
    step_file_list = _step_file_list(shared_steps_dir, agent_steps_dir)

    if not _has_agent_file(step_file_list):
        return [
            _load_failure_step(
                _AGENT_STEPS_STEP_NAME,
                f"found no agent steps in {agent_steps_dir}, so the image's own steps did not run",
            )
        ]

    step_file_list.sort()
    step_list = []

    for _, _, module_path in step_file_list:
        step_list.extend(_module_step_list(module_path))

    return step_list


# ------------------------------------------------------------------------------
# Running and printing
# ------------------------------------------------------------------------------

def _run_step(step: Check) -> CheckResult:
    try:
        result = step.function()
    except Exception as e:
        return failed(
            f"raised {type(e).__name__}: {e}",
            "this is a bug in sbx-init or a broken image; " + rebuild_hint(),
        )

    if not isinstance(result, CheckResult):
        return failed(
            f"returned {type(result).__name__} instead of a CheckResult",
            "this is a bug in sbx-init or a broken image; " + rebuild_hint(),
        )

    return result


def _outcome_lines(name: str, result: CheckResult) -> list[str]:
    detail = one_line(result.detail)

    if result.passed:
        return [f"OK: {name}: {detail}"]

    return [f"FAIL: {name}: {detail}", f"{_FIX_LINE_INDENT}fix: {one_line(result.hint)}"]


def _write_line(output: TextIO, line: str) -> None:
    output.write(line + "\n")
    output.flush()


def _write_outcome(output: TextIO, name: str, result: CheckResult) -> None:
    for line in _outcome_lines(name, result):
        output.write(line + "\n")

    output.flush()


def _stop_at(output: TextIO, name: str, result: CheckResult) -> int:
    _write_outcome(output, name, result)
    _write_line(output, f"sbx-init: stopped at {name}")

    return 1


def _run_steps(step_list: list[Check], output: TextIO) -> tuple[int, str]:
    passed_count = 0

    for step in step_list:
        result = _run_step(step)
        _write_outcome(output, step.name, result)

        if not result.passed:
            return passed_count, step.name

        passed_count += 1

    return passed_count, ""


# ------------------------------------------------------------------------------
# Lock and marker
# ------------------------------------------------------------------------------

def _take_lock(lock_file: Path) -> TextIO | None:
    handle = open(lock_file, "a+")

    try:
        fcntl.flock(handle, fcntl.LOCK_EX | fcntl.LOCK_NB)
    except BlockingIOError:
        handle.close()

        return None

    return handle


def _marker_failure(action_text: str, marker_file: Path, error: OSError) -> CheckResult:
    return failed(
        f"cannot {action_text} {marker_file}: {error.strerror}",
        "check that /home/sandbox is writable; " + rebuild_hint(),
    )


def _run_locked(shared_steps_dir: Path, agent_steps_dir: Path, marker_file: Path, output: TextIO) -> int:
    try:
        marker_file.unlink(missing_ok=True)
    except OSError as e:
        return _stop_at(output, _MARKER_STEP_NAME, _marker_failure("remove", marker_file, e))

    passed_count, stopped_name = _run_steps(collect_steps(shared_steps_dir, agent_steps_dir), output)

    if stopped_name:
        _write_line(output, f"sbx-init: stopped at {stopped_name}")

        return 1

    try:
        marker_file.touch()
    except OSError as e:
        return _stop_at(output, _MARKER_STEP_NAME, _marker_failure("write", marker_file, e))

    _write_line(output, f"sbx-init: {passed_count} steps passed; run sbx-selfcheck to check the sandbox")

    return 0


def run_init(shared_steps_dir: Path, agent_steps_dir: Path, marker_file: Path, lock_file: Path, output: TextIO) -> int:
    try:
        lock_handle = _take_lock(lock_file)
    except OSError as e:
        return _stop_at(
            output,
            _LOCK_STEP_NAME,
            failed(f"cannot open {lock_file}: {e.strerror}", "check that /home/sandbox is writable; " + rebuild_hint()),
        )

    if lock_handle is None:
        return _stop_at(
            output,
            _LOCK_STEP_NAME,
            failed("another sbx-init is running", "wait for it to finish, then run sbx-init again"),
        )

    try:
        return _run_locked(shared_steps_dir, agent_steps_dir, marker_file, output)
    finally:
        lock_handle.close()


# ------------------------------------------------------------------------------
# Interruptions
# ------------------------------------------------------------------------------
# A closed terminal (SIGHUP) or a stop (SIGTERM) would end Python without running
# any finally block, so both raise KeyboardInterrupt like Ctrl-C; the GSD step
# then stops its installer, and the lock closes last.
# ------------------------------------------------------------------------------

def _raise_on_stop_signals() -> None:
    for signal_number in _STOP_SIGNAL_LIST:
        signal.signal(signal_number, signal.default_int_handler)


def _report_interrupted() -> None:
    try:
        print(_INTERRUPTED_TEXT, file=sys.stderr)
    except OSError:
        pass


# ------------------------------------------------------------------------------
# The launcher's entry
# ------------------------------------------------------------------------------

def main(argument_list: list[str]) -> int:
    if argument_list:
        print(_USAGE_TEXT, file=sys.stderr)

        return 2

    _raise_on_stop_signals()

    try:
        return run_init(SHARED_STEPS_DIR, paths.AGENT_STEPS_DIR, paths.INIT_MARKER_FILE, paths.INIT_LOCK_FILE, sys.stdout)
    except KeyboardInterrupt:
        _report_interrupted()

        return _INTERRUPTED_EXIT_CODE
