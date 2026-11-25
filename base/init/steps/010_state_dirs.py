# --------------------------------------------------------------------------------
# Step: the state directories
# --------------------------------------------------------------------------------
# The image puts this file in /usr/local/lib/sbx-init/steps/.
# --------------------------------------------------------------------------------

import os
from pathlib import Path

from check_result import Check, CheckResult, failed, make_state_dir, passed
from hints import rebuild_hint
from paths import STATE_DIR, state_dir_name_list


# --------------------------------------------------------------------------------
# State directories
# --------------------------------------------------------------------------------

def _is_outside_state(name: str) -> bool:
    return name.startswith("/") or ".." in Path(name).parts


def make_state_dirs_result(state_dir: Path, state_dirs_text: str) -> CheckResult:
    dir_name_list = state_dir_name_list(state_dirs_text)

    for name in dir_name_list:
        if _is_outside_state(name):
            return failed(
                f"SBX_STATE_DIRS names '{name}', which is not a directory name under {state_dir}",
                rebuild_hint(),
            )

    for name in dir_name_list:
        dir_failure = make_state_dir(state_dir / name)

        if dir_failure is not None:
            return dir_failure

    return passed(f"{', '.join(dir_name_list)} exist under {state_dir}")


# --------------------------------------------------------------------------------
# Step entries
# --------------------------------------------------------------------------------

def _step_state_dirs() -> CheckResult:
    return make_state_dirs_result(STATE_DIR, os.environ.get("SBX_STATE_DIRS", ""))


STEP_LIST = [Check("state-dirs", _step_state_dirs)]
