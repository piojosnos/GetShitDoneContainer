# --------------------------------------------------------------------------------
# The sbx-init runner: loads the step files, runs them in order and prints
# --------------------------------------------------------------------------------
# Prints one OK or FAIL line per step, and a fix line under each FAIL. The image
# puts this file in /usr/local/lib/sbx-init/.
# --------------------------------------------------------------------------------

import fcntl
import signal
import sys
from pathlib import Path
from types import ModuleType
from typing import Callable, TextIO

import paths
from check_result import Check, CheckResult, failed
from hints import rebuild_hint
from step_files import StepFileKind, load_failure_check, load_list, load_module, run_one, write_outcome


# --------------------------------------------------------------------------------
# Constants
# --------------------------------------------------------------------------------

SHARED_STEPS_DIR = Path(__file__).resolve().parent / "steps"
_FILE_KIND = StepFileKind(
    list_name="STEP_LIST",
    item_word="steps",
    module_prefix="sbx_init_step_",
    owner_text="sbx-init",
    pass_word="OK",
)
_USAGE_TEXT = "Usage: sbx-init (no arguments)"
_LOCK_STEP_NAME = "lock"
_MARKER_STEP_NAME = "marker"
_AGENT_STEPS_STEP_NAME = "load-agent-steps"
_SHARED_GROUP = 0
_AGENT_GROUP = 1
_INTERRUPTED_EXIT_CODE = 130
_INTERRUPTED_TEXT = "sbx-init: interrupted; run sbx-init again"
_STOP_SIGNAL_LIST = [signal.SIGHUP, signal.SIGTERM]


# --------------------------------------------------------------------------------
# Loading the steps
# --------------------------------------------------------------------------------
# Shared and agent step files sort together by file name, so the shared 800 step
# runs between an agent's 050 and 900; sbx-selfcheck runs shared checks first.
# --------------------------------------------------------------------------------

def load_step_module(module_path: Path) -> ModuleType:
    return load_module(module_path, _FILE_KIND.module_prefix)


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
            load_failure_check(
                _AGENT_STEPS_STEP_NAME,
                f"found no agent steps in {agent_steps_dir}, so the image's own steps did not run",
            )
        ]

    step_file_list.sort()
    step_list = []

    for _, _, module_path in step_file_list:
        step_list.extend(load_list(module_path, _FILE_KIND))

    return step_list


# --------------------------------------------------------------------------------
# Running and printing
# --------------------------------------------------------------------------------

def _write_line(line: str, output: TextIO) -> None:
    output.write(line + "\n")
    output.flush()


def _stop_at(name: str, result: CheckResult, output: TextIO) -> int:
    write_outcome(name, result, _FILE_KIND, output)
    _write_line(f"sbx-init: stopped at {name}", output)

    return 1


def _run_steps(step_list: list[Check], output: TextIO) -> tuple[int, str]:
    passed_count = 0

    for step in step_list:
        result = run_one(step, _FILE_KIND)
        write_outcome(step.name, result, _FILE_KIND, output)

        if not result.passed:
            return passed_count, step.name

        passed_count += 1

    return passed_count, ""


# --------------------------------------------------------------------------------
# Lock and marker
# --------------------------------------------------------------------------------

def _take_lock(lock_file: Path, flock_function: Callable[[TextIO, int], None] = fcntl.flock) -> TextIO | None:
    handle = open(lock_file, "a+")

    try:
        flock_function(handle, fcntl.LOCK_EX | fcntl.LOCK_NB)
    except BlockingIOError:
        handle.close()

        return None
    except OSError:
        handle.close()

        raise

    return handle


def _dir_writable_hint(file: Path) -> str:
    return f"check that {file.parent} is writable; " + rebuild_hint()


def _marker_failure(action_text: str, marker_file: Path, error: OSError) -> CheckResult:
    return failed(
        f"cannot {action_text} {marker_file}: {error.strerror}",
        _dir_writable_hint(marker_file),
    )


def _run_locked(shared_steps_dir: Path, agent_steps_dir: Path, marker_file: Path, output: TextIO) -> int:
    try:
        marker_file.unlink(missing_ok=True)
    except OSError as e:
        return _stop_at(_MARKER_STEP_NAME, _marker_failure("remove", marker_file, e), output)

    passed_count, stopped_name = _run_steps(collect_steps(shared_steps_dir, agent_steps_dir), output)

    if stopped_name:
        _write_line(f"sbx-init: stopped at {stopped_name}", output)

        return 1

    try:
        marker_file.touch()
    except OSError as e:
        return _stop_at(_MARKER_STEP_NAME, _marker_failure("write", marker_file, e), output)

    _write_line(f"sbx-init: {passed_count} steps passed; run sbx-selfcheck to check the sandbox", output)

    return 0


def run_init(shared_steps_dir: Path, agent_steps_dir: Path, marker_file: Path, lock_file: Path, output: TextIO) -> int:
    try:
        lock_handle = _take_lock(lock_file)
    except OSError as e:
        return _stop_at(
            _LOCK_STEP_NAME,
            failed(f"cannot open {lock_file}: {e.strerror}", _dir_writable_hint(lock_file)),
            output,
        )

    if lock_handle is None:
        return _stop_at(
            _LOCK_STEP_NAME,
            failed("another sbx-init is running", "wait for it to finish, then run sbx-init again"),
            output,
        )

    try:
        return _run_locked(shared_steps_dir, agent_steps_dir, marker_file, output)
    finally:
        lock_handle.close()


# --------------------------------------------------------------------------------
# Interruptions
# --------------------------------------------------------------------------------
# A closed terminal (SIGHUP) or a stop (SIGTERM) would end Python without running
# any finally block, so both raise KeyboardInterrupt like Ctrl-C; the GSD step
# then stops its installer, and the lock closes last.
# --------------------------------------------------------------------------------

def _raise_on_stop_signals() -> None:
    for signal_number in _STOP_SIGNAL_LIST:
        signal.signal(signal_number, signal.default_int_handler)


def _report_interrupted() -> None:
    try:
        print(_INTERRUPTED_TEXT, file=sys.stderr)
    except OSError:
        pass


# --------------------------------------------------------------------------------
# The launcher's entry
# --------------------------------------------------------------------------------

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
