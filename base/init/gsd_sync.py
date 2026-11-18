# ------------------------------------------------------------------------------
# The GSD sync into an agent config directory
# ------------------------------------------------------------------------------
# Runs the image's own installer, offline, and reports only its outcome; the
# self-check compares the synced version with the pin. The image puts this file
# in /usr/local/lib/sbx-init/.
# ------------------------------------------------------------------------------

import os
import signal
import subprocess
import tempfile
from pathlib import Path
from typing import Mapping

from check_result import CheckResult, failed, make_state_dir, passed
from hints import rebuild_hint


# ------------------------------------------------------------------------------
# Constants
# ------------------------------------------------------------------------------

GSD_INSTALLER_COMMAND = "gsd-core"
GSD_TIME_LIMIT_SECONDS = 300
_LOG_PREFIX = "sbx-init-gsd-"


# ------------------------------------------------------------------------------
# The sync
# ------------------------------------------------------------------------------
# The installer waits forever on a directory it cannot create, so the directory is made
# first and a directory that cannot be made fails here at once.
# ------------------------------------------------------------------------------

def gsd_sync_result(
    config_dir: Path,
    agent_option: str,
    installer_command: str = GSD_INSTALLER_COMMAND,
    time_limit_seconds: int = GSD_TIME_LIMIT_SECONDS,
    environment_map: Mapping[str, str] = os.environ,
    log_dir: Path | None = None,
) -> CheckResult:
    dir_failure = make_state_dir(config_dir)

    if dir_failure is not None:
        return dir_failure

    argument_list = [installer_command, agent_option, "--global", "--config-dir", str(config_dir)]

    return _run_installer(argument_list, config_dir, time_limit_seconds, environment_map, log_dir)


# ------------------------------------------------------------------------------
# Running the installer
# ------------------------------------------------------------------------------
# The installer runs in its own session, so a time limit or an interruption of
# sbx-init kills everything it started before the lock is released. Its output
# file is kept only on failure.
# ------------------------------------------------------------------------------

def _run_installer(
    argument_list: list[str],
    config_dir: Path,
    time_limit_seconds: int,
    environment_map: Mapping[str, str],
    log_dir: Path | None,
) -> CheckResult:
    with tempfile.NamedTemporaryFile(prefix=_LOG_PREFIX, suffix=".log", dir=log_dir, delete=False) as log_handle:
        log_file = Path(log_handle.name)

        try:
            process = subprocess.Popen(
                argument_list,
                stdin=subprocess.DEVNULL,
                stdout=log_handle,
                stderr=subprocess.STDOUT,
                start_new_session=True,
                env=dict(environment_map),
            )
        except FileNotFoundError:
            log_file.unlink(missing_ok=True)

            return failed(f"{argument_list[0]} is not on PATH", rebuild_hint())

        try:
            timed_out = _wait_or_stop(process, time_limit_seconds)
        except BaseException:
            try:
                _kill_group(process)
            finally:
                log_file.unlink(missing_ok=True)

            raise

    return _outcome_result(process.returncode, timed_out, config_dir, time_limit_seconds, log_file)


def _wait_or_stop(process: subprocess.Popen, time_limit_seconds: int) -> bool:
    try:
        process.wait(timeout=time_limit_seconds)
    except subprocess.TimeoutExpired:
        _kill_group(process)

        return True

    return False


def _kill_group(process: subprocess.Popen) -> None:
    try:
        os.killpg(process.pid, signal.SIGKILL)
    except ProcessLookupError:
        pass

    process.wait()


# ------------------------------------------------------------------------------
# Outcome
# ------------------------------------------------------------------------------

def _outcome_result(
    exit_code: int,
    timed_out: bool,
    config_dir: Path,
    time_limit_seconds: int,
    log_file: Path,
) -> CheckResult:
    hint = f"read {log_file}, fix what it names, then run sbx-init again"

    if timed_out:
        return failed(
            f"the GSD installer did not finish within {time_limit_seconds} s and was stopped; "
            f"its output is in {log_file}",
            hint,
        )

    if exit_code != 0:
        return failed(
            f"the GSD installer exited {exit_code} (last line: '{_last_line(log_file)}'); "
            f"its output is in {log_file}",
            hint,
        )

    log_file.unlink(missing_ok=True)

    return passed(f"the GSD installer finished into {config_dir}")


def _last_line(log_file: Path) -> str:
    last_line = ""

    for line in log_file.read_text(errors="replace").splitlines():
        if line.strip():
            last_line = line.strip()

    return last_line
