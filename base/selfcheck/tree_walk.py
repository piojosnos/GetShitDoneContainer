# ------------------------------------------------------------------------------
# The one folder walk of the checks
# ------------------------------------------------------------------------------
# Every check that walks folders goes through walk_tree and keeps its own rule in
# a hook. The image puts this file in /usr/local/lib/sbx-selfcheck/.
# ------------------------------------------------------------------------------

import os
import stat
from dataclasses import dataclass
from enum import Enum
from pathlib import Path
from typing import Callable


# ------------------------------------------------------------------------------
# Hook and problem types
# ------------------------------------------------------------------------------
# A hook gets an entry and its lstat result. It returns False to keep the walk out
# of that folder; the return value of a file or a link entry is not used.
# ------------------------------------------------------------------------------

EntryHook = Callable[[Path, os.stat_result], bool]


class ProblemKind(Enum):
    MISSING_ROOT = "missing"
    UNREADABLE_FOLDER = "unreadable"


@dataclass(frozen=True)
class WalkProblem:
    path: Path
    kind: ProblemKind


# ------------------------------------------------------------------------------
# The walk
# ------------------------------------------------------------------------------
# Links are never followed. A permission error on a folder or on an entry of it
# is returned as a problem; any other error surfaces.
# ------------------------------------------------------------------------------

def walk_tree(root_list: list[Path], on_entry: EntryHook) -> list[WalkProblem]:
    problem_list = []

    for root in root_list:
        _walk_root(root, on_entry, problem_list)

    return problem_list


def _walk_root(root: Path, on_entry: EntryHook, problem_list: list[WalkProblem]) -> None:
    try:
        root_stat = root.lstat()
    except FileNotFoundError:
        problem_list.append(WalkProblem(root, ProblemKind.MISSING_ROOT))

        return
    except PermissionError:
        problem_list.append(WalkProblem(root, ProblemKind.UNREADABLE_FOLDER))

        return

    if not on_entry(root, root_stat) or not stat.S_ISDIR(root_stat.st_mode):
        return

    def on_error(error: OSError) -> None:
        if not isinstance(error, FileNotFoundError):
            problem_list.append(WalkProblem(Path(error.filename), ProblemKind.UNREADABLE_FOLDER))

    for folder, dir_name_list, file_name_list in root.walk(on_error=on_error, follow_symlinks=False):
        dir_name_list[:] = _visit_folder(folder, dir_name_list + file_name_list, on_entry, problem_list)


def _visit_folder(
    folder: Path,
    name_list: list[str],
    on_entry: EntryHook,
    problem_list: list[WalkProblem],
) -> list[str]:
    descend_name_list = []

    for name in name_list:
        entry = folder / name

        try:
            entry_stat = entry.lstat()
        except FileNotFoundError:
            continue
        except PermissionError:
            # A stat needs search permission on the folder, so every other entry would fail the same way.
            problem_list.append(WalkProblem(folder, ProblemKind.UNREADABLE_FOLDER))

            return []

        if on_entry(entry, entry_stat) and stat.S_ISDIR(entry_stat.st_mode):
            descend_name_list.append(name)

    return descend_name_list
