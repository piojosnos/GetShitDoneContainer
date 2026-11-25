# --------------------------------------------------------------------------------
# Where a new sandbox directory may sit: the host path text and the overlap rules
# --------------------------------------------------------------------------------
# Directories are compared as directories, not as text, so a symlink, a .. part,
# /tmp against /private/tmp and a different letter case on a macOS disk all count
# as the same directory.
# --------------------------------------------------------------------------------

import os

from sbx.cli import SbxError


# --------------------------------------------------------------------------------
# The host path text
# --------------------------------------------------------------------------------
# Refused: empty, relative, a line break, and an empty, . or .. part. ~ is not
# expanded. The overlap checks follow symlinks (see paths_overlap).
# --------------------------------------------------------------------------------

def check_host_path(raw_path: str) -> str:
    if raw_path == "":
        raise SbxError("the host path is empty")

    if not raw_path.startswith("/"):
        raise SbxError(f"'{raw_path}' is not an absolute path; ~ and relative paths are not expanded")

    if "\n" in raw_path:
        raise SbxError("the host path has a line break")

    stripped_path = raw_path.rstrip("/")

    if stripped_path == "":
        return "/"

    padded_path = stripped_path + "/"

    if "//" in padded_path or "/./" in padded_path or "/../" in padded_path:
        raise SbxError(f"'{raw_path}' has an empty, . or .. part")

    return stripped_path


# --------------------------------------------------------------------------------
# Finding the directory a path stands for
# --------------------------------------------------------------------------------
# The base is the deepest directory of the path that exists, with every symlink
# and .. part resolved. The tail is the list of parts below it that do not exist
# yet, empty when the path exists.
# --------------------------------------------------------------------------------

def locate_dir(path: str) -> tuple[str, list[str]]:
    if not path.startswith("/") or "\0" in path:
        raise ValueError("not an absolute path that can be resolved")

    walk_path = os.path.realpath(path)
    tail_list: list[str] = []

    while not os.path.isdir(walk_path):
        walk_path, part = os.path.split(walk_path)
        tail_list.insert(0, part)

    return walk_path, tail_list


# --------------------------------------------------------------------------------
# Comparing two located paths
# --------------------------------------------------------------------------------
# _dir_within compares the directories themselves with samefile at each step, not
# their spelling. Tails sit below the same existing directory; they are compared
# per part and without letter case, because the default macOS disk ignores case:
# /x/sbx and /x/sbx-other do not overlap, and an empty tail holds every tail.
# --------------------------------------------------------------------------------

def _dir_within(directory: str, ancestor: str) -> bool:
    walk_path = directory

    while True:
        if os.path.samefile(walk_path, ancestor):
            return True

        parent = os.path.dirname(walk_path)

        if parent == walk_path:
            return False

        walk_path = parent


# --------------------------------------------------------------------------------

def _tails_overlap(first_list: list[str], second_list: list[str]) -> bool:
    shared_length = min(len(first_list), len(second_list))

    for index in range(shared_length):
        if first_list[index].casefold() != second_list[index].casefold():
            return False

    return True


# --------------------------------------------------------------------------------
# paths_overlap
# --------------------------------------------------------------------------------
# True when the two paths are one directory or one holds the other. Both paths are
# resolved here, so a caller cannot forget to. A part that does not exist yet is
# compared as text below the deepest part that does. Whatever cannot be resolved
# counts as an overlap.
# --------------------------------------------------------------------------------

def paths_overlap(first: str, second: str) -> bool:
    try:
        first_base, first_tail_list = locate_dir(first)
        second_base, second_tail_list = locate_dir(second)

        if os.path.samefile(first_base, second_base):
            return _tails_overlap(first_tail_list, second_tail_list)

        if not second_tail_list and _dir_within(first_base, second_base):
            return True

        if not first_tail_list and _dir_within(second_base, first_base):
            return True
    except (OSError, ValueError):
        return True

    return False
