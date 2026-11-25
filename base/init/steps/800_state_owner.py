# --------------------------------------------------------------------------------
# Step: give root-owned state back to the sandbox user
# --------------------------------------------------------------------------------
# The image puts this file in /usr/local/lib/sbx-init/steps/.
# --------------------------------------------------------------------------------

import os
from pathlib import Path
from typing import Callable, Mapping

from check_result import Check, CheckResult, capped_problem_detail, failed, passed
from paths import STATE_DIR
from root_owned_scan import SKIPPED_STATE_DIR_SET, UNREADABLE_SUFFIX, owner_fix_hint, scan_owned_state
from users import SANDBOX_GID, SANDBOX_UID

_GIVE_BACK_ROUND_LIMIT = 3


# --------------------------------------------------------------------------------
# One round of giving back
# --------------------------------------------------------------------------------

def _scanned_name_list(state_dir: Path, from_uid: int) -> list[str]:
    name_list = []

    for reported_name in scan_owned_state(state_dir, from_uid, SKIPPED_STATE_DIR_SET):
        name_list.append(reported_name.removesuffix(UNREADABLE_SUFFIX))

    return name_list


# --------------------------------------------------------------------------------

def _give_back_round(
    state_dir: Path,
    name_list: list[str],
    to_uid: int,
    to_gid: int,
    chown_function: Callable[[Path, int, int], None],
) -> tuple[int, list[str]]:
    given_back_count = 0
    problem_list = []

    for relative_name in name_list:
        try:
            chown_function(state_dir / relative_name, to_uid, to_gid)
            given_back_count += 1
        except OSError as e:
            problem_list.append(f"{relative_name}: {e.strerror}")

    return given_back_count, problem_list


# --------------------------------------------------------------------------------
# Give-back result
# --------------------------------------------------------------------------------
# A round that gave paths back may have opened directories the scan could not read,
# so the scan and the give-back repeat. Whatever is still owned by from_uid after
# the last round is a failure.
# --------------------------------------------------------------------------------

def give_back_state_result(
    state_dir: Path,
    from_uid: int,
    to_uid: int,
    to_gid: int,
    chown_function: Callable[[Path, int, int], None] = os.lchown,
    environment_map: Mapping[str, str] = os.environ,
) -> CheckResult:
    given_back_count = 0
    round_count = 0
    name_list = _scanned_name_list(state_dir, from_uid)

    while name_list and round_count < _GIVE_BACK_ROUND_LIMIT:
        done_count, problem_list = _give_back_round(state_dir, name_list, to_uid, to_gid, chown_function)
        given_back_count += done_count

        if problem_list:
            return failed(capped_problem_detail(problem_list), owner_fix_hint(state_dir, environment_map))

        round_count += 1
        name_list = _scanned_name_list(state_dir, from_uid)

    if name_list:
        problem_list = []

        for name in name_list:
            problem_list.append(f"{name}: still owned by uid {from_uid}")

        return failed(capped_problem_detail(problem_list), owner_fix_hint(state_dir, environment_map))

    return passed(f"{given_back_count} paths given back to sandbox")


# --------------------------------------------------------------------------------
# Step entries
# --------------------------------------------------------------------------------

def _step_state_owner() -> CheckResult:
    return give_back_state_result(STATE_DIR, 0, SANDBOX_UID, SANDBOX_GID)


STEP_LIST = [Check("state-owner", _step_state_owner)]
