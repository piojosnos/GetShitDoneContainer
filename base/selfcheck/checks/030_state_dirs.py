# --------------------------------------------------------------------------------
# Checks: the state directories exist and can be written
# --------------------------------------------------------------------------------
# The image puts this file in /usr/local/lib/sbx-selfcheck/checks/.
# --------------------------------------------------------------------------------

import os
import tempfile
from pathlib import Path

from check_result import Check, CheckResult, failed, passed
from hints import init_hint, state_writable_hint
from paths import STATE_DIR, state_dir_name_list

_STATE_WRITE_PROBE_PREFIX = ".sbx-selfcheck-"


# --------------------------------------------------------------------------------
# State directories
# --------------------------------------------------------------------------------

def state_dirs_result(state_dir: Path, state_dirs_text: str) -> CheckResult:
    dir_name_list = state_dir_name_list(state_dirs_text)
    missing_list = []

    for dir_name in dir_name_list:
        if not (state_dir / dir_name).is_dir():
            missing_list.append(dir_name)

    if missing_list:
        return failed(
            f"missing under {state_dir}: {', '.join(missing_list)}",
            init_hint(),
        )

    return passed(f"{', '.join(dir_name_list)} exist under {state_dir}")


# --------------------------------------------------------------------------------
# State writable
# --------------------------------------------------------------------------------

def state_writable_result(state_dir: Path) -> CheckResult:
    try:
        probe_descriptor, probe_name = tempfile.mkstemp(dir=state_dir, prefix=_STATE_WRITE_PROBE_PREFIX)
    except OSError as e:
        return failed(
            f"cannot make a file in {state_dir}: {e}",
            state_writable_hint(),
        )

    try:
        os.close(probe_descriptor)
    finally:
        Path(probe_name).unlink()

    return passed(f"{state_dir} is writable")


# --------------------------------------------------------------------------------
# Check entries
# --------------------------------------------------------------------------------

def _check_state_dirs() -> CheckResult:
    return state_dirs_result(STATE_DIR, os.environ.get("SBX_STATE_DIRS", ""))


# --------------------------------------------------------------------------------

def _check_state_writable() -> CheckResult:
    return state_writable_result(STATE_DIR)


CHECK_LIST = [
    Check("state-dirs", _check_state_dirs),
    Check("state-writable", _check_state_writable),
]
