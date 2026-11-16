# ------------------------------------------------------------------------------
# Checks: the state folders exist and can be written
# ------------------------------------------------------------------------------
# The image puts this file in /usr/local/lib/sbx-selfcheck/checks/.
# ------------------------------------------------------------------------------

import os
import tempfile
from pathlib import Path

from check_result import Check, CheckResult, failed, passed
from hints import init_hint, restart_hint
from paths import BASE_STATE_DIR_LIST, STATE_DIR

_STATE_WRITE_PROBE_PREFIX = ".sbx-selfcheck-"


# ------------------------------------------------------------------------------
# State folders
# ------------------------------------------------------------------------------

def state_folders_result(state_dir: Path, state_dirs_text: str) -> CheckResult:
    folder_list = BASE_STATE_DIR_LIST + state_dirs_text.split()
    missing_list = []

    for folder in folder_list:
        if not (state_dir / folder).is_dir():
            missing_list.append(folder)

    if missing_list:
        return failed(
            f"missing under {state_dir}: {', '.join(missing_list)}",
            init_hint(),
        )

    return passed(f"{', '.join(folder_list)} exist under {state_dir}")


# ------------------------------------------------------------------------------
# State writable
# ------------------------------------------------------------------------------

def state_writable_result(state_dir: Path) -> CheckResult:
    try:
        probe_descriptor, probe_name = tempfile.mkstemp(dir=state_dir, prefix=_STATE_WRITE_PROBE_PREFIX)
    except OSError as e:
        return failed(
            f"cannot make a file in {state_dir}: {e}",
            "make the state folder of the sandbox writable by your Mac user, then " + restart_hint(),
        )

    try:
        os.close(probe_descriptor)
    finally:
        Path(probe_name).unlink()

    return passed(f"{state_dir} is writable")


# ------------------------------------------------------------------------------
# Check entries
# ------------------------------------------------------------------------------

def _check_state_folders() -> CheckResult:
    return state_folders_result(STATE_DIR, os.environ.get("SBX_STATE_DIRS", ""))


def _check_state_writable() -> CheckResult:
    return state_writable_result(STATE_DIR)


CHECK_LIST = [
    Check("state-folders", _check_state_folders),
    Check("state-writable", _check_state_writable),
]
