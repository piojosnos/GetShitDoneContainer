# ------------------------------------------------------------------------------
# Step: the state folders
# ------------------------------------------------------------------------------
# The image puts this file in /usr/local/lib/sbx-init/steps/.
# ------------------------------------------------------------------------------

import os
from pathlib import Path

from check_result import Check, CheckResult, failed, passed
from paths import BASE_STATE_DIR_LIST, STATE_DIR


# ------------------------------------------------------------------------------
# State folders
# ------------------------------------------------------------------------------

def _folder_name_list(state_dirs_text: str) -> list[str]:
    folder_list = []

    for name in BASE_STATE_DIR_LIST + state_dirs_text.split():
        if name not in folder_list:
            folder_list.append(name)

    return folder_list


def make_state_folders_result(state_dir: Path, state_dirs_text: str) -> CheckResult:
    folder_list = _folder_name_list(state_dirs_text)

    for name in folder_list:
        try:
            (state_dir / name).mkdir(parents=True, exist_ok=True)
        except OSError as e:
            return failed(
                f"cannot make {state_dir / name}: {e.strerror}",
                "make the state folder of the sandbox writable by your Mac user, then run sbx-init again",
            )

    return passed(f"{', '.join(folder_list)} exist under {state_dir}")


# ------------------------------------------------------------------------------
# Step entries
# ------------------------------------------------------------------------------

def _step_state_folders() -> CheckResult:
    return make_state_folders_result(STATE_DIR, os.environ.get("SBX_STATE_DIRS", ""))


STEP_LIST = [Check("state-folders", _step_state_folders)]
