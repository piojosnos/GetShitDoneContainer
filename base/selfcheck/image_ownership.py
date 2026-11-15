# ------------------------------------------------------------------------------
# Root-owned image files
# ------------------------------------------------------------------------------
# Everything under the roots of an image belongs to root and cannot be changed by
# group or others. Folders, the sbx commands, the start hooks and the launcher
# are executable. The image puts this file in /usr/local/lib/sbx-selfcheck/.
# ------------------------------------------------------------------------------

import os
import stat
from dataclasses import dataclass
from pathlib import Path

from check_result import CheckResult, capped_problem_detail, failed, passed
from hints import rebuild_hint
from image_roots import COMMAND_DIR, COMMAND_PREFIX, HOOK_DIR, LAUNCHER_FILE
from tree_walk import ProblemKind, WalkProblem, walk_tree

_EXECUTABLE_BITS = 0o111
_GROUP_OTHER_WRITE_BITS = 0o022
_LIBRARY_SUFFIX = ".sh"


# ------------------------------------------------------------------------------
# The rules for one entry
# ------------------------------------------------------------------------------
# A link is checked for its owner only: its own mode means nothing, and the file
# it points to is walked in its own right. A sourced shell library such as
# sbx-start-lib.sh is the one sbx file that is not executable.
# ------------------------------------------------------------------------------

@dataclass(frozen=True)
class ImageRules:
    owner_uid: int = 0
    owner_gid: int = 0
    command_dir: Path = COMMAND_DIR
    hook_dir: Path = HOOK_DIR
    launcher_file: Path = LAUNCHER_FILE


def _must_be_executable(path: Path, entry_stat: os.stat_result, rules: ImageRules) -> bool:
    if stat.S_ISDIR(entry_stat.st_mode) or path == rules.launcher_file:
        return True

    if path.parent == rules.hook_dir:
        return True

    return path.parent == rules.command_dir and path.name.startswith(COMMAND_PREFIX) and path.suffix != _LIBRARY_SUFFIX


def _entry_problem_list(path: Path, entry_stat: os.stat_result, rules: ImageRules) -> list[str]:
    problem_list = []

    if entry_stat.st_uid != rules.owner_uid or entry_stat.st_gid != rules.owner_gid:
        problem_list.append(
            f"{path} is owned by {entry_stat.st_uid}:{entry_stat.st_gid}, expected {rules.owner_uid}:{rules.owner_gid}"
        )

    if stat.S_ISLNK(entry_stat.st_mode):
        return problem_list

    mode = stat.S_IMODE(entry_stat.st_mode)

    if mode & _GROUP_OTHER_WRITE_BITS:
        problem_list.append(f"{path} is writable by group or others ({mode:o})")

    if _must_be_executable(path, entry_stat, rules) and mode & _EXECUTABLE_BITS != _EXECUTABLE_BITS:
        problem_list.append(f"{path} is not executable ({mode:o})")

    return problem_list


# ------------------------------------------------------------------------------
# The image ownership result
# ------------------------------------------------------------------------------

def _walk_problem_text(walk_problem: WalkProblem) -> str:
    if walk_problem.kind == ProblemKind.MISSING_ROOT:
        return f"{walk_problem.path} is missing"

    return f"{walk_problem.path} cannot be opened"


def image_ownership_problem_list(root_list: list[Path], rules: ImageRules = ImageRules()) -> list[str]:
    problem_list = []

    def check_entry(path: Path, entry_stat: os.stat_result) -> bool:
        problem_list.extend(_entry_problem_list(path, entry_stat, rules))

        return True

    for walk_problem in walk_tree(root_list, check_entry):
        problem_list.append(_walk_problem_text(walk_problem))

    return problem_list


def image_ownership_result(root_list: list[Path], rules: ImageRules = ImageRules()) -> CheckResult:
    problem_list = image_ownership_problem_list(root_list, rules)

    if problem_list:
        return failed(capped_problem_detail(problem_list), rebuild_hint())

    return passed(f"{len(root_list)} roots: everything under them is owned by root and not writable by group or others")
