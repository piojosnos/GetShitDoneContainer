# ------------------------------------------------------------------------------
# Check: no state path is owned by root
# ------------------------------------------------------------------------------
# A root-owned path breaks the agent's next write. The image puts this file in
# /usr/local/lib/sbx-selfcheck/checks/.
# ------------------------------------------------------------------------------

import os
import stat
from dataclasses import dataclass
from pathlib import Path
from typing import Callable, Mapping

from check_result import Check, CheckResult, failed, passed
from hints import mac_hint, sandbox_name
from paths import STATE_DIR
from users import SANDBOX_GID, SANDBOX_UID

_OWNER_FIX_IMAGE = "sbx-base:local"
_SKIPPED_STATE_DIR_SET = {"cache/npm", "cache/uv", "m2"}
_GSD_SYNC_FOLDER_SET = {"gsd-core", "hooks", "scripts"}
_REPORTED_PATH_LIMIT = 10
_UNREADABLE_SUFFIX = " (unreadable)"


# ------------------------------------------------------------------------------
# The scan of the state folder
# ------------------------------------------------------------------------------

@dataclass(frozen=True)
class _ScanRules:
    state_dir: Path
    owner_uid: int
    skipped_relative_set: set[str]
    tolerated_folder_set: set[str]


def _is_tolerated_path(relative_path: Path, tolerated_folder_set: set[str]) -> bool:
    return len(relative_path.parts) >= 2 and relative_path.parts[1] in tolerated_folder_set


def _mark_unreadable_folder(reported_list: list[str], relative_dir: Path, tolerated_folder_set: set[str]) -> None:
    if _is_tolerated_path(relative_dir, tolerated_folder_set):
        return

    if relative_dir.as_posix() in reported_list:
        reported_list.remove(relative_dir.as_posix())

    reported_list.append(relative_dir.as_posix() + _UNREADABLE_SUFFIX)


def _read_entry_list(folder: Path) -> list[Path]:
    return list(folder.iterdir())


def _entry_list_or_none(
    current_dir: Path,
    rules: _ScanRules,
    entry_reader: Callable[[Path], list[Path]],
    reported_list: list[str],
) -> list[Path] | None:
    try:
        return entry_reader(current_dir)
    except FileNotFoundError:
        return None
    except OSError:
        relative_dir = current_dir.relative_to(rules.state_dir)
        _mark_unreadable_folder(reported_list, relative_dir, rules.tolerated_folder_set)

        return None


def _scan_entry_list(
    entry_list: list[Path],
    current_dir: Path,
    rules: _ScanRules,
    reported_list: list[str],
    pending_dir_list: list[Path],
) -> int:
    tolerated_count = 0

    for entry in entry_list:
        relative_path = entry.relative_to(rules.state_dir)

        if relative_path.as_posix() in rules.skipped_relative_set:
            continue

        try:
            entry_stat = entry.lstat()
        except FileNotFoundError:
            continue
        except PermissionError:
            # An entry stat needs search permission on its folder, so every other entry would fail the same way.
            relative_dir = current_dir.relative_to(rules.state_dir)
            _mark_unreadable_folder(reported_list, relative_dir, rules.tolerated_folder_set)
            break

        if entry_stat.st_uid == rules.owner_uid:
            if _is_tolerated_path(relative_path, rules.tolerated_folder_set):
                tolerated_count += 1
            else:
                reported_list.append(relative_path.as_posix())

        if stat.S_ISDIR(entry_stat.st_mode):
            pending_dir_list.append(entry)

    return tolerated_count


def scan_owned_state(
    state_dir: Path,
    owner_uid: int,
    skipped_relative_set: set[str],
    tolerated_folder_set: set[str],
    entry_reader: Callable[[Path], list[Path]] = _read_entry_list,
) -> tuple[list[str], int]:
    rules = _ScanRules(state_dir, owner_uid, skipped_relative_set, tolerated_folder_set)
    reported_list = []
    tolerated_count = 0
    pending_dir_list = [state_dir]

    while pending_dir_list:
        current_dir = pending_dir_list.pop()
        entry_list = _entry_list_or_none(current_dir, rules, entry_reader, reported_list)

        if entry_list is None:
            continue

        tolerated_count += _scan_entry_list(entry_list, current_dir, rules, reported_list, pending_dir_list)

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
