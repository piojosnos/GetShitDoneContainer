# ------------------------------------------------------------------------------
# Protected paths
# ------------------------------------------------------------------------------
# Nothing under a protected path may be writable by the sandbox user or be a
# mount point. The image puts this file in /usr/local/lib/sbx-selfcheck/.
# ------------------------------------------------------------------------------

import os
from pathlib import Path

from check_result import CheckResult, failed, passed
from hints import rebuild_hint
from mounts import MOUNTINFO_FILE, read_mount_point_set
from paths import is_under, path_is_present

_REPORTED_PROBLEM_LIMIT = 10


# ------------------------------------------------------------------------------
# Problems under one path
# ------------------------------------------------------------------------------

def _entry_list_under(path: Path) -> list[Path]:
    entry_list = [path]

    for current_dir, dir_name_list, file_name_list in path.walk(follow_symlinks=False):
        for name in dir_name_list + file_name_list:
            entry_list.append(current_dir / name)

    return entry_list


def _writable_entry_problem_list(path: Path) -> list[str]:
    problem_list = []

    for entry in _entry_list_under(path):
        if os.access(entry, os.W_OK):
            problem_list.append(f"{entry} is writable")

    return problem_list


def _mount_point_problem_list(path: Path, mount_point_found_set: set[str]) -> list[str]:
    problem_list = []

    for mount_point in sorted(mount_point_found_set):
        if is_under(mount_point, str(path)):
            problem_list.append(f"{mount_point} is a mount point")

    return problem_list


def _protected_paths_problem_list(path_list: list[Path], mount_point_found_set: set[str]) -> list[str]:
    problem_list = []

    for path in path_list:
        if not path_is_present(path):
            problem_list.append(f"{path} is missing")
            continue

        problem_list.extend(_writable_entry_problem_list(path))
        problem_list.extend(_mount_point_problem_list(path, mount_point_found_set))

    return problem_list


# ------------------------------------------------------------------------------
# The protected paths result
# ------------------------------------------------------------------------------

def protected_paths_result(path_list: list[Path], mountinfo_file: Path = MOUNTINFO_FILE) -> CheckResult:
    problem_list = _protected_paths_problem_list(path_list, read_mount_point_set(mountinfo_file))

    if problem_list:
        return failed(
            f"{len(problem_list)} problems: " + "; ".join(problem_list[:_REPORTED_PROBLEM_LIMIT]),
            rebuild_hint(),
        )

    path_text_list = []

    for path in path_list:
        path_text_list.append(str(path))

    return passed(f"nothing under {', '.join(path_text_list)} is writable or mounted")
