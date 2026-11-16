# ------------------------------------------------------------------------------
# The GSD sync into an agent's config folder
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

from check_result import CheckResult, failed, passed
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

def gsd_sync_result(
    config_dir: Path,
    agent_option: str,
    installer_command: str = GSD_INSTALLER_COMMAND,
    time_limit_seconds: int = GSD_TIME_LIMIT_SECONDS,
    environment_map: Mapping[str, str] = os.environ,
    log_dir: Path | None = None,
) -> CheckResult:
    folder_failure = _make_config_folder(config_dir)

    if folder_failure is not None:
        return folder_failure

    argument_list = [installer_command, agent_option, "--global", "--config-dir", str(config_dir)]

    return _run_installer(argument_list, config_dir, time_limit_seconds, environment_map, log_dir)


# ------------------------------------------------------------------------------
# Making the folder
# ------------------------------------------------------------------------------
# The installer waits forever on a folder it cannot create, so the folder is made
# first and a folder that cannot be made fails here at once.
# ------------------------------------------------------------------------------

def _make_config_folder(config_dir: Path) -> CheckResult | None:
    try:
        config_dir.mkdir(parents=True, exist_ok=True)
    except OSError as e:
        return failed(
            f"cannot make {config_dir}: {e.strerror}",
            "make the state folder of the sandbox writable by your Mac user, then run sbx-init again",
        )

    return None


# ------------------------------------------------------------------------------
# Running the installer
# ------------------------------------------------------------------------------
# The installer gets its own session, so a stuck one is stopped together with
# everything it started. Its output goes to a file that is kept only on failure.
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

        timed_out = _wait_or_stop(process, time_limit_seconds)

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
