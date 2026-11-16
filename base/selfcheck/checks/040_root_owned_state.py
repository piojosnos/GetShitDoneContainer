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
from hints import mac_hint, sandbox_name
from paths import STATE_DIR
from tree_walk import ProblemKind, walk_tree
from users import SANDBOX_GID, SANDBOX_UID

_OWNER_FIX_IMAGE = "sbx-base:local"
_SKIPPED_STATE_DIR_SET = {"cache/npm", "cache/uv", "m2"}
_GSD_SYNC_FOLDER_SET = {"gsd-core", "hooks", "scripts"}
_REPORTED_PATH_LIMIT = 10
_UNREADABLE_SUFFIX = " (unreadable)"


# ------------------------------------------------------------------------------
# The scan of the state folder
# ------------------------------------------------------------------------------

def _is_tolerated_path(relative_path: Path, tolerated_folder_set: set[str]) -> bool:
    return len(relative_path.parts) >= 2 and relative_path.parts[1] in tolerated_folder_set


def _mark_unreadable_folder(reported_list: list[str], relative_dir: Path) -> None:
    if relative_dir.as_posix() in reported_list:
        reported_list.remove(relative_dir.as_posix())

    reported_list.append(relative_dir.as_posix() + _UNREADABLE_SUFFIX)


def scan_owned_state(
    state_dir: Path,
    owner_uid: int,
    skipped_relative_set: set[str],
    tolerated_folder_set: set[str],
) -> tuple[list[str], int]:
    reported_list = []
    tolerated_count = 0

    def scan_entry(entry: Path, entry_stat: os.stat_result) -> bool:
        nonlocal tolerated_count
        relative_path = entry.relative_to(state_dir)

        if relative_path.as_posix() in skipped_relative_set:
            return False

        if entry_stat.st_uid != owner_uid or entry == state_dir:
            return True

        if _is_tolerated_path(relative_path, tolerated_folder_set):
            tolerated_count += 1
        else:
            reported_list.append(relative_path.as_posix())

        return True

    for walk_problem in walk_tree([state_dir], scan_entry):
        relative_dir = walk_problem.path.relative_to(state_dir)

        if walk_problem.kind == ProblemKind.UNREADABLE_FOLDER and not _is_tolerated_path(relative_dir, tolerated_folder_set):
            _mark_unreadable_folder(reported_list, relative_dir)

    return sorted(reported_list), tolerated_count


# ------------------------------------------------------------------------------
# Root-owned state result
# ------------------------------------------------------------------------------

def _owner_fix_hint(state_dir: Path, environment_map: Mapping[str, str] = os.environ) -> str:
    return mac_hint(
        "give the paths back to the sandbox user from a throwaway root container, "
        "since the sandbox cannot change owners",
        "docker run --rm --network none -u root --entrypoint chown "
        f"--volumes-from sbx-{sandbox_name(environment_map)} {_OWNER_FIX_IMAGE} -R {SANDBOX_UID}:{SANDBOX_GID} {state_dir}",
    )


def root_owned_state_result(
    state_dir: Path,
    owner_uid: int,
    environment_map: Mapping[str, str] = os.environ,
) -> CheckResult:
    reported_list, tolerated_count = scan_owned_state(state_dir, owner_uid, _SKIPPED_STATE_DIR_SET, _GSD_SYNC_FOLDER_SET)

    if not reported_list:
        return passed(f"no root-owned path under state/ outside the GSD sync folders ({tolerated_count} tolerated)")

    return failed(
        f"{len(reported_list)} paths under state/ are owned by uid {owner_uid} or unreadable: "
        + ", ".join(reported_list[:_REPORTED_PATH_LIMIT]),
        _owner_fix_hint(state_dir, environment_map),
    )


# ------------------------------------------------------------------------------
# Check entries
# ------------------------------------------------------------------------------

def _check_no_root_owned_state() -> CheckResult:
    return root_owned_state_result(STATE_DIR, 0)


CHECK_LIST = [Check("no-root-owned-state", _check_no_root_owned_state)]
