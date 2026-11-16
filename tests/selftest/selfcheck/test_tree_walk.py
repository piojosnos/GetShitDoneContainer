# ------------------------------------------------------------------------------
# Tests of the folder walk
# ------------------------------------------------------------------------------
# The walk runs on real files, real permissions and links inside tmp_path.
# ------------------------------------------------------------------------------

import errno
import os
import stat
from pathlib import Path

import pytest

import tree_walk
from helpers import write_file
from tree_walk import ProblemKind, WalkProblem


# ------------------------------------------------------------------------------
# Constants and helpers
# ------------------------------------------------------------------------------

class FailingStatPath(type(Path())):
    def lstat(self):
        raise OSError(errno.EIO, "I/O error")


def visited_by(root_list: list[Path], descend_name_set: set[str] | None = None):
    visited_list = []

    def record(entry: Path, entry_stat: os.stat_result) -> bool:
        visited_list.append(entry)

        return descend_name_set is None or entry.name not in descend_name_set

    problem_list = tree_walk.walk_tree(root_list, record)

    return sorted(visited_list), problem_list


# ------------------------------------------------------------------------------
# Walk
# ------------------------------------------------------------------------------

def test_the_walk_calls_the_hook_for_the_root_and_every_entry_below_it(tmp_path):
    folder1 = tmp_path / "folder1"
    write_file(folder1 / "sub1" / "file1")
    write_file(folder1 / "file2")

    visited_list, problem_list = visited_by([folder1])

    assert visited_list == sorted([folder1, folder1 / "sub1", folder1 / "sub1" / "file1", folder1 / "file2"])
    assert problem_list == []


def test_the_walk_hands_the_hook_the_lstat_result_of_the_entry(tmp_path):
    write_file(tmp_path / "folder1" / "file1")
    (tmp_path / "folder1" / "link1").symlink_to(tmp_path / "folder1" / "file1")
    seen_map = {}

    def record(entry: Path, entry_stat: os.stat_result) -> bool:
        seen_map[entry.name] = entry_stat

        return True

    tree_walk.walk_tree([tmp_path / "folder1"], record)

    assert stat.S_ISDIR(seen_map["folder1"].st_mode)
    assert stat.S_ISREG(seen_map["file1"].st_mode)
    assert stat.S_ISLNK(seen_map["link1"].st_mode)


def test_the_walk_does_not_follow_a_link_to_a_folder(tmp_path):
    folder1 = tmp_path / "folder1"
    write_file(tmp_path / "outside1" / "file1")
    folder1.mkdir()
    (folder1 / "link1").symlink_to(tmp_path / "outside1")

    visited_list, _ = visited_by([folder1])

    assert visited_list == [folder1, folder1 / "link1"]


def test_the_walk_takes_several_roots_and_a_file_or_a_link_as_a_root(tmp_path):
    write_file(tmp_path / "folder1" / "file1")
    write_file(tmp_path / "file2")
    (tmp_path / "link1").symlink_to(tmp_path / "folder1")

    visited_list, problem_list = visited_by([tmp_path / "folder1", tmp_path / "file2", tmp_path / "link1"])

    assert visited_list == sorted(
        [tmp_path / "folder1", tmp_path / "folder1" / "file1", tmp_path / "file2", tmp_path / "link1"]
    )
    assert problem_list == []


def test_the_walk_stays_out_of_a_folder_the_hook_prunes(tmp_path):
    folder1 = tmp_path / "folder1"
    write_file(folder1 / "skipped1" / "deeper1" / "file1")
    write_file(folder1 / "kept1" / "file2")

    visited_list, _ = visited_by([folder1], {"skipped1"})

    assert visited_list == sorted([folder1, folder1 / "skipped1", folder1 / "kept1", folder1 / "kept1" / "file2"])


def test_the_walk_reports_a_missing_root_and_goes_on(tmp_path):
    write_file(tmp_path / "folder2" / "file1")

    visited_list, problem_list = visited_by([tmp_path / "folder1", tmp_path / "folder2"])

    assert visited_list == [tmp_path / "folder2", tmp_path / "folder2" / "file1"]
    assert problem_list == [WalkProblem(tmp_path / "folder1", ProblemKind.MISSING_ROOT)]


@pytest.mark.skipif(os.getuid() == 0, reason="root can open a mode 000 folder")
def test_the_walk_reports_a_folder_it_cannot_open_and_goes_on(tmp_path, restorable_mode):
    folder1 = tmp_path / "folder1"
    write_file(folder1 / "private1" / "file1")
    write_file(folder1 / "file2")
    restorable_mode(folder1 / "private1", 0o000)

    visited_list, problem_list = visited_by([folder1])

    assert visited_list == sorted([folder1, folder1 / "private1", folder1 / "file2"])
    assert problem_list == [WalkProblem(folder1 / "private1", ProblemKind.UNREADABLE_FOLDER)]


@pytest.mark.skipif(os.getuid() == 0, reason="root can open a mode 444 folder")
def test_the_walk_reports_a_folder_it_can_list_but_not_search_once_and_stays_out_of_it(tmp_path, restorable_mode):
    folder1 = tmp_path / "folder1"
    write_file(folder1 / "private1" / "file1")
    write_file(folder1 / "private1" / "file2")
    write_file(folder1 / "private1" / "sub1" / "file3")
    restorable_mode(folder1 / "private1", 0o444)

    visited_list, problem_list = visited_by([folder1])

    assert visited_list == [folder1, folder1 / "private1"]
    assert problem_list == [WalkProblem(folder1 / "private1", ProblemKind.UNREADABLE_FOLDER)]


def test_the_walk_lets_an_error_other_than_permission_surface(tmp_path):
    folder1 = tmp_path / "folder1"
    write_file(folder1 / "file1")

    with pytest.raises(OSError) as raised:
        visited_by([FailingStatPath(folder1)])

    assert raised.value.errno == errno.EIO
