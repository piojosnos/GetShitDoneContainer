# ------------------------------------------------------------------------------
# Tests of the root-owned state check
# ------------------------------------------------------------------------------
# The check runs on real files, real permissions and links inside tmp_path.
# ------------------------------------------------------------------------------

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
    write_file(state1 / "cache" / "npm" / "file3")
    write_file(outside1 / "file4")
    (state1 / "sub1" / "link1").symlink_to(outside1)

    return state1


def make_fourteen_path_tree(state1: Path) -> None:
    for number in range(13):
        write_file(state1 / "sub1" / f"file{number:02d}")


# ------------------------------------------------------------------------------
# Root-owned state
# ------------------------------------------------------------------------------

def test_root_owned_state_passes_on_a_tree_owned_by_another_uid(state_tree):
    result = root_owned_state.root_owned_state_result(state_tree, os.getuid() + 1)

    assert result.passed
    assert result.detail == "no root-owned path under state/"


def test_a_root_owned_path_in_a_gsd_core_folder_fails_the_check(tmp_path):
    state1 = tmp_path / "state1"
    write_file(state1 / "sub1" / "gsd-core" / "file1")

    result = root_owned_state.root_owned_state_result(state1, os.getuid(), NAMED_ENVIRONMENT)

    assert not result.passed
    assert "sub1/gsd-core/file1" in result.detail


def test_paths_in_the_skipped_cache_folders_are_not_listed(tmp_path):
    state1 = tmp_path / "state1"
    write_file(state1 / "cache" / "npm" / "file1")
    write_file(state1 / "m2" / "file2")

    result = root_owned_state.root_owned_state_result(state1, os.getuid(), NAMED_ENVIRONMENT)

    assert not result.passed
    assert "cache/npm" not in result.detail
    assert "m2" not in result.detail


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
