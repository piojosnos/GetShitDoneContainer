# --------------------------------------------------------------------------------
# The scan for root-owned state paths
# --------------------------------------------------------------------------------
# The image puts this file in /usr/local/lib/sbx-selfcheck/; sbx-init and
# sbx-selfcheck both use it.
# --------------------------------------------------------------------------------

import os
from pathlib import Path
from typing import Mapping

from hints import host_hint, sandbox_name
from tree_walk import ProblemKind, walk_tree
from users import SANDBOX_GID, SANDBOX_UID

_OWNER_FIX_IMAGE = "sbx-base:local"
UNREADABLE_SUFFIX = " (unreadable)"
SKIPPED_STATE_DIR_SET = {"cache/npm", "cache/uv", "m2"}


# --------------------------------------------------------------------------------
# The scan of the state directory
# --------------------------------------------------------------------------------

def _mark_unreadable_dir(reported_list: list[str], relative_dir: Path) -> None:
    if relative_dir.as_posix() in reported_list:
        reported_list.remove(relative_dir.as_posix())

    reported_list.append(relative_dir.as_posix() + UNREADABLE_SUFFIX)


# --------------------------------------------------------------------------------

def scan_owned_state(state_dir: Path, owner_uid: int, skipped_relative_set: set[str]) -> list[str]:
    reported_list = []

    def scan_entry(entry: Path, entry_stat: os.stat_result) -> bool:
        relative_path = entry.relative_to(state_dir)

        if relative_path.as_posix() in skipped_relative_set:
            return False

        if entry_stat.st_uid == owner_uid and entry != state_dir:
            reported_list.append(relative_path.as_posix())

        return True

    for walk_problem in walk_tree([state_dir], scan_entry):
        if walk_problem.kind == ProblemKind.UNREADABLE_DIR:
            _mark_unreadable_dir(reported_list, walk_problem.path.relative_to(state_dir))

    return sorted(reported_list)


# --------------------------------------------------------------------------------
# The host fix
# --------------------------------------------------------------------------------

def owner_fix_hint(state_dir: Path, environment_map: Mapping[str, str] = os.environ) -> str:
    return host_hint(
        "give the paths back to the sandbox user from a throwaway root container, "
        "since the sandbox cannot change owners",
        "docker run --rm --network none -u root --entrypoint chown "
        f"--volumes-from sbx-{sandbox_name(environment_map)} {_OWNER_FIX_IMAGE} -R {SANDBOX_UID}:{SANDBOX_GID} {state_dir}",
    )
