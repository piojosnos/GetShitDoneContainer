# ------------------------------------------------------------------------------
# Step: the state folders
# ------------------------------------------------------------------------------
# The image puts this file in /usr/local/lib/sbx-init/steps/.
# ------------------------------------------------------------------------------

import os
from pathlib import Path

from check_result import Check, CheckResult, failed, make_state_folder, passed
from hints import rebuild_hint
from paths import STATE_DIR, state_folder_name_list


# ------------------------------------------------------------------------------
# State folders
# ------------------------------------------------------------------------------

def _is_outside_state(name: str) -> bool:
    return name.startswith("/") or ".." in Path(name).parts


def make_state_folders_result(state_dir: Path, state_dirs_text: str) -> CheckResult:
    folder_list = state_folder_name_list(state_dirs_text)

    for name in folder_list:
        if _is_outside_state(name):
            return failed(
                f"SBX_STATE_DIRS names '{name}', which is not a folder name under {state_dir}",
                rebuild_hint(),
            )

    for name in folder_list:
        folder_failure = make_state_folder(state_dir / name)

        if folder_failure is not None:
            return folder_failure

    return passed(f"{', '.join(folder_list)} exist under {state_dir}")


# ------------------------------------------------------------------------------
# Step entries
# ------------------------------------------------------------------------------

def _step_state_folders() -> CheckResult:
    return make_state_folders_result(STATE_DIR, os.environ.get("SBX_STATE_DIRS", ""))


STEP_LIST = [Check("state-folders", _step_state_folders)]
