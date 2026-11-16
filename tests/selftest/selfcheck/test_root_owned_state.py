# ------------------------------------------------------------------------------
# Tests of the root-owned state check
# ------------------------------------------------------------------------------
# The scan runs on real files, real permissions and links inside tmp_path.
# ------------------------------------------------------------------------------

import errno
import os
from pathlib import Path

import pytest

import check_result
from helpers import load_shared_check, run_lines, write_file

root_owned_state = load_shared_check("040_root_owned_state")


# ------------------------------------------------------------------------------
# Constants and helpers
# ------------------------------------------------------------------------------

NAMED_ENVIRONMENT = {"SBX_NAME": "name1"}


@pytest.fixture
def state_tree(tmp_path):
    state1 = tmp_path / "state1"
    outside1 = tmp_path / "outside1"
    write_file(state1 / "sub1" / "notes1")
    write_file(state1 / "sub1" / "gsd-core" / "file1")
    write_file(state1 / "sub1" / "gsd-core" / "deeper1" / "file2")
    write_file(state1 / "cache" / "npm" / "file3")
    write_file(outside1 / "file4")
    (state1 / "sub1" / "link1").symlink_to(outside1)

    return state1


def make_fourteen_path_tree(state1: Path) -> None:
    for number in range(13):
        write_file(state1 / "sub1" / f"file{number:02d}")


class FailingStatPath(type(Path())):
    def lstat(self):
        raise OSError(errno.EIO, "I/O error")


# ------------------------------------------------------------------------------
# Root-owned state
# ------------------------------------------------------------------------------

def test_scan_owned_state_skips_tolerated_skipped_and_linked_trees(state_tree):
    path_list = root_owned_state.scan_owned_state(state_tree, os.getuid(), {"cache/npm"}, {"gsd-core"})[0]

    assert path_list == ["cache", "sub1", "sub1/link1", "sub1/notes1"]


def test_scan_owned_state_finds_nothing_for_another_owner(state_tree):
    assert root_owned_state.scan_owned_state(state_tree, os.getuid() + 1, set(), set())[0] == []


def test_scan_owned_state_reports_a_link_without_following_it(state_tree):
    path_list = root_owned_state.scan_owned_state(state_tree, os.getuid(), set(), set())[0]

    assert "sub1/link1" in path_list

    for path in path_list:
        assert not path.startswith("sub1/link1/")


def test_root_owned_state_fails_with_the_total_and_at_most_ten_paths(tmp_path):
    state1 = tmp_path / "state1"
    make_fourteen_path_tree(state1)

    result = root_owned_state.root_owned_state_result(state1, os.getuid(), NAMED_ENVIRONMENT)

    assert not result.passed
    assert "14 paths" in result.detail
    assert result.detail.count("sub1") == 10
    assert result.hint == (
        "give the paths back to the sandbox user from a throwaway root container, "
        "since the sandbox cannot change owners: on the Mac run: "
        "docker run --rm --network none -u root --entrypoint chown "
        f"--volumes-from sbx-name1 sbx-base:local -R 1000:1000 {state1}"
    )


def test_root_owned_state_hint_says_name_when_sbx_name_is_unset(tmp_path):
    state1 = tmp_path / "state1"
    make_fourteen_path_tree(state1)

    result = root_owned_state.root_owned_state_result(state1, os.getuid(), {})

    assert not result.passed
    assert "--volumes-from sbx-NAME sbx-base:local -R 1000:1000" in result.hint


def test_root_owned_state_prints_the_mac_owner_fix_under_its_fail_line(tmp_path, agents1):
    state1 = tmp_path / "state1"
    make_fourteen_path_tree(state1)

    def scan_state1():
        return root_owned_state.root_owned_state_result(state1, os.getuid(), NAMED_ENVIRONMENT)

    _, line_list = run_lines([check_result.Check("no-root-owned-state", scan_state1)], agents1)

    assert line_list[0].startswith("FAIL: no-root-owned-state: 14 paths under state/")
    assert line_list[1] == (
        "      fix: give the paths back to the sandbox user from a throwaway root container, "
        "since the sandbox cannot change owners: on the Mac run: "
        "docker run --rm --network none -u root --entrypoint chown "
        f"--volumes-from sbx-name1 sbx-base:local -R 1000:1000 {state1}"
    )


def test_scan_owned_state_counts_tolerated_paths_and_skips_cache_folders(tmp_path):
    state1 = tmp_path / "state1"
    write_file(state1 / "sub1" / "gsd-core" / "file1")
    write_file(state1 / "sub1" / "hooks" / "file2")
    write_file(state1 / "cache" / "npm" / "file3")
    write_file(state1 / "m2" / "file4")
    (state1 / "sub1" / "gsd-core" / "link1").symlink_to(tmp_path)

    result = root_owned_state.scan_owned_state(state1, os.getuid(), {"cache/npm", "m2"}, {"gsd-core", "hooks", "scripts"})

    assert result == (["cache", "sub1"], 5)


@pytest.mark.skipif(os.getuid() == 0, reason="root can open a mode 000 folder")
def test_scan_owned_state_marks_a_reported_folder_it_cannot_open(tmp_path, restorable_mode):
    state1 = tmp_path / "state1"
    write_file(state1 / "sub1" / "private1" / "file1")
    restorable_mode(state1 / "sub1" / "private1", 0o000)

    result = root_owned_state.scan_owned_state(state1, os.getuid(), set(), set())

    assert result == (["sub1", "sub1/private1 (unreadable)"], 0)


@pytest.mark.skipif(os.getuid() == 0, reason="root can open a mode 000 folder")
def test_scan_owned_state_reports_an_unreadable_folder_of_another_owner(tmp_path, restorable_mode):
    state1 = tmp_path / "state1"
    write_file(state1 / "sub1" / "private1" / "file1")
    restorable_mode(state1 / "sub1" / "private1", 0o000)

    result = root_owned_state.scan_owned_state(state1, os.getuid() + 1, set(), set())

    assert result == (["sub1/private1 (unreadable)"], 0)


@pytest.mark.skipif(os.getuid() == 0, reason="root can open a mode 000 folder")
def test_scan_owned_state_tolerates_an_unreadable_folder_in_a_sync_folder(tmp_path, restorable_mode):
    state1 = tmp_path / "state1"
    write_file(state1 / "sub1" / "gsd-core" / "file1")
    restorable_mode(state1 / "sub1" / "gsd-core", 0o000)

    result = root_owned_state.scan_owned_state(state1, os.getuid(), set(), {"gsd-core"})

    assert result == (["sub1"], 1)


def test_scan_owned_state_finds_nothing_in_a_missing_state_folder(tmp_path):
    assert root_owned_state.scan_owned_state(tmp_path / "state1", os.getuid(), set(), set()) == ([], 0)


@pytest.mark.skipif(os.getuid() == 0, reason="root can open a mode 000 folder")
def test_root_owned_state_names_an_unreadable_folder_with_the_mac_fix(tmp_path, restorable_mode):
    state1 = tmp_path / "state1"
    write_file(state1 / "sub1" / "private1" / "file1")
    restorable_mode(state1 / "sub1" / "private1", 0o000)

    result = root_owned_state.root_owned_state_result(state1, os.getuid())

    assert not result.passed
    assert "or unreadable" in result.detail
    assert "sub1/private1 (unreadable)" in result.detail
    assert "raised" not in result.detail
    assert result.hint.startswith("give the paths back to the sandbox user")
    assert str(state1) in result.hint


@pytest.mark.skipif(os.getuid() == 0, reason="root can open a mode 444 folder")
def test_scan_owned_state_marks_a_folder_it_can_list_but_not_search(tmp_path, restorable_mode):
    state1 = tmp_path / "state1"
    write_file(state1 / "sub1" / "private1" / "file1")
    write_file(state1 / "sub1" / "private1" / "file2")
    restorable_mode(state1 / "sub1" / "private1", 0o444)

    result = root_owned_state.scan_owned_state(state1, os.getuid(), set(), set())

    assert result == (["sub1", "sub1/private1 (unreadable)"], 0)


@pytest.mark.skipif(os.getuid() == 0, reason="root can open a mode 444 folder")
def test_scan_owned_state_tolerates_a_folder_it_cannot_search_in_a_sync_folder(tmp_path, restorable_mode):
    state1 = tmp_path / "state1"
    write_file(state1 / "sub1" / "gsd-core" / "file1")
    restorable_mode(state1 / "sub1" / "gsd-core", 0o444)

    result = root_owned_state.scan_owned_state(state1, os.getuid(), set(), {"gsd-core"})

    assert result == (["sub1"], 1)


@pytest.mark.skipif(os.getuid() == 0, reason="root can open a mode 444 folder")
def test_root_owned_state_prints_the_owner_fix_for_a_folder_it_cannot_search(tmp_path, restorable_mode, agents1):
    state1 = tmp_path / "state1"
    write_file(state1 / "sub1" / "private1" / "file1")
    write_file(state1 / "sub1" / "private1" / "file2")
    restorable_mode(state1 / "sub1" / "private1", 0o444)

    def scan_state1():
        return root_owned_state.root_owned_state_result(state1, os.getuid(), NAMED_ENVIRONMENT)

    _, line_list = run_lines([check_result.Check("no-root-owned-state", scan_state1)], agents1)

    assert line_list[0] == (
        f"FAIL: no-root-owned-state: 2 paths under state/ are owned by uid {os.getuid()} "
        "or unreadable: sub1, sub1/private1 (unreadable)"
    )
    assert "raised" not in line_list[0]
    assert line_list[1].startswith(
        "      fix: give the paths back to the sandbox user from a throwaway root container"
    )
    assert line_list[1].endswith(f"--volumes-from sbx-name1 sbx-base:local -R 1000:1000 {state1}")


def test_scan_owned_state_lets_an_entry_error_other_than_permission_surface(tmp_path):
    state1 = tmp_path / "state1"
    write_file(state1 / "file1")

    with pytest.raises(OSError) as raised:
        root_owned_state.scan_owned_state(FailingStatPath(state1), os.getuid(), set(), set())

    assert raised.value.errno == errno.EIO


def test_root_owned_state_names_the_tolerated_count_on_a_pass(tmp_path):
    state1 = tmp_path / "state1"
    state1.mkdir()

    result = root_owned_state.root_owned_state_result(state1, os.getuid() + 1)

    assert result.passed
    assert "outside the GSD sync folders (0 tolerated)" in result.detail


def test_state_walk_never_opens_a_file(state_tree, restorable_mode):
    unreadable1 = state_tree / "sub1" / "notes1"
    restorable_mode(unreadable1, 0o000)

    path_list = root_owned_state.scan_owned_state(state_tree, os.getuid(), set(), set())[0]

    assert "sub1/notes1" in path_list
