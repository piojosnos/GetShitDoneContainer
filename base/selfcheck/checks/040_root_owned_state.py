# ------------------------------------------------------------------------------
# Check: no state path is owned by root
# ------------------------------------------------------------------------------
# A root-owned path breaks the agent's next write. The image puts this file in
# /usr/local/lib/sbx-selfcheck/checks/.
# ------------------------------------------------------------------------------

import os
from pathlib import Path
from typing import Mapping

from check_result import Check, CheckResult, failed, passed
from paths import STATE_DIR
from root_owned_scan import SKIPPED_STATE_DIR_SET, owner_fix_hint, scan_owned_state

_REPORTED_PATH_LIMIT = 10


# ------------------------------------------------------------------------------
# Root-owned state result
# ------------------------------------------------------------------------------

def root_owned_state_result(
    state_dir: Path,
    owner_uid: int,
    environment_map: Mapping[str, str] = os.environ,
) -> CheckResult:
    reported_list = scan_owned_state(state_dir, owner_uid, SKIPPED_STATE_DIR_SET)

    if not reported_list:
        return passed("no root-owned path under state/")

    return failed(
        f"{len(reported_list)} paths under state/ are owned by uid {owner_uid} or unreadable: "
        + ", ".join(reported_list[:_REPORTED_PATH_LIMIT]),
        owner_fix_hint(state_dir, environment_map),
    )


# ------------------------------------------------------------------------------
# Check entries
# ------------------------------------------------------------------------------

def _check_no_root_owned_state() -> CheckResult:
    return root_owned_state_result(STATE_DIR, 0)


CHECK_LIST = [Check("no-root-owned-state", _check_no_root_owned_state)]
