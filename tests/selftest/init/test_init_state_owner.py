# ------------------------------------------------------------------------------
# Tests of the state owner step
# ------------------------------------------------------------------------------
# Real files and links in tmp_path; the current uid stands in for root. A stand-in
# chown function that removes a file plays the owner change, since a non-root
# test cannot give a file to another user.
# ------------------------------------------------------------------------------

import os
from pathlib import Path

import pytest

from init_helpers import REPO_DIR, load_step

state_owner_step = load_step(REPO_DIR / "base" / "init" / "steps" / "800_state_owner.py")


# ------------------------------------------------------------------------------
# Helpers
# ------------------------------------------------------------------------------

def write_file(path: Path) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text("text1")


def recording_lchown(chowned_list: list[Path]):
    def chown_and_record(path: Path, uid: int, gid: int) -> None:
        chowned_list.append(path)
        os.lchown(path, uid, gid)

    return chown_and_record


def removing_chown(chowned_list: list[Path]):
    def remove_instead(path: Path, uid: int, gid: int) -> None:
        chowned_list.append(path)
        path.unlink()

    return remove_instead


@pytest.fixture
def state_tree(tmp_path):
    state1 = tmp_path / "state1"
    outside1 = tmp_path / "outside1"
    write_file(state1 / "sub1" / "notes1")
    write_file(state1 / "cache" / "npm" / "file1")
    write_file(outside1 / "file2")
    (state1 / "sub1" / "link1").symlink_to(outside1)

    return state1


# ------------------------------------------------------------------------------
# Giving back
# ------------------------------------------------------------------------------

def test_the_owner_change_is_made_on_every_path_and_each_one_is_counted(tmp_path):
    state1 = tmp_path / "state1"
    write_file(state1 / "file1")
    write_file(state1 / "file2")
    (state1 / "link1").symlink_to(tmp_path)
    chowned_list = []

    result = state_owner_step.give_back_state_result(
        state1, os.getuid(), os.getuid(), os.getgid(), removing_chown(chowned_list)
    )

    assert result.passed
    assert result.detail == "3 paths given back to sandbox"
    assert sorted(path.name for path in chowned_list) == ["file1", "file2", "link1"]


def test_the_real_lchown_is_accepted_for_every_path_but_a_file_still_owned_after_three_rounds_fails(tmp_path):
    state1 = tmp_path / "state1"
    write_file(state1 / "file1")

    result = state_owner_step.give_back_state_result(state1, os.getuid(), os.getuid(), os.getgid())

    assert not result.passed
    assert result.detail == f"1 problems: file1: still owned by uid {os.getuid()}"
    assert "Operation not permitted" not in result.detail


def test_a_link_to_a_dir_outside_the_tree_is_changed_as_a_link_and_the_dir_is_not_visited(state_tree, tmp_path):
    chowned_list = []

    state_owner_step.give_back_state_result(
        state_tree, os.getuid(), os.getuid(), os.getgid(), recording_lchown(chowned_list)
    )

    assert state_tree / "sub1" / "link1" in chowned_list

    for path in chowned_list:
        assert tmp_path / "outside1" not in path.parents
        assert path != tmp_path / "outside1"
        assert (state_tree / "sub1" / "link1") not in path.parents


def test_a_file_under_a_skipped_cache_dir_is_never_changed(state_tree):
    chowned_list = []

    state_owner_step.give_back_state_result(
        state_tree, os.getuid(), os.getuid(), os.getgid(), recording_lchown(chowned_list)
    )

    assert state_tree / "cache" / "npm" / "file1" not in chowned_list
    assert state_tree / "cache" / "npm" not in chowned_list


def test_a_tree_with_nothing_owned_by_the_old_owner_passes_with_zero_given_back(state_tree):
    result = state_owner_step.give_back_state_result(state_tree, os.getuid() + 1, os.getuid(), os.getgid())

    assert result.passed
    assert result.detail == "0 paths given back to sandbox"


def test_a_missing_state_dir_passes_with_zero_given_back(tmp_path):
    result = state_owner_step.give_back_state_result(tmp_path / "state1", os.getuid(), os.getuid(), os.getgid())

    assert result.passed
    assert result.detail == "0 paths given back to sandbox"


def test_a_second_run_after_a_give_back_passes_with_zero_given_back(tmp_path):
    state1 = tmp_path / "state1"
    write_file(state1 / "file1")

    first_result = state_owner_step.give_back_state_result(
        state1, os.getuid(), os.getuid(), os.getgid(), removing_chown([])
    )
    second_result = state_owner_step.give_back_state_result(state1, os.getuid(), os.getuid(), os.getgid())

    assert first_result.detail == "1 paths given back to sandbox"
    assert second_result.passed
    assert second_result.detail == "0 paths given back to sandbox"


# ------------------------------------------------------------------------------
# Failures
# ------------------------------------------------------------------------------

@pytest.mark.skipif(os.getuid() == 0, reason="root may give a file to uid 0")
def test_the_real_lchown_to_root_fails_with_at_most_ten_paths_and_the_container_named_in_the_fix(tmp_path):
    state1 = tmp_path / "state1"

    for number in range(13):
        write_file(state1 / f"file{number:02d}")

    result = state_owner_step.give_back_state_result(
        state1, os.getuid(), 0, 0, environment_map={"SBX_NAME": "name1"}
    )

    assert not result.passed
    assert result.detail.startswith("13 problems: ")
    assert "Operation not permitted" in result.detail
    assert result.detail.count("file") == 10
    assert "--volumes-from sbx-name1" in result.hint
    assert f"-R 1000:1000 {state1}" in result.hint


@pytest.mark.skipif(os.getuid() == 0, reason="root may give a file to uid 0")
def test_a_failed_give_back_deletes_nothing(tmp_path):
    state1 = tmp_path / "state1"
    write_file(state1 / "file1")

    state_owner_step.give_back_state_result(state1, os.getuid(), 0, 0)

    assert (state1 / "file1").read_text() == "text1"


def test_a_path_still_owned_after_three_rounds_fails_naming_it(tmp_path):
    state1 = tmp_path / "state1"
    write_file(state1 / "file1")
    chowned_list = []

    result = state_owner_step.give_back_state_result(
        state1, os.getuid(), os.getuid(), os.getgid(), recording_lchown(chowned_list)
    )

    assert not result.passed
    assert len(chowned_list) == 3
    assert "file1: still owned by uid" in result.detail


@pytest.mark.skipif(os.getuid() == 0, reason="root can open a mode 000 directory")
def test_a_dir_the_scan_cannot_read_at_first_is_given_back_and_then_its_content_is_reached(tmp_path):
    state1 = tmp_path / "state1"
    write_file(state1 / "private1" / "file1")
    (state1 / "private1").chmod(0o000)
    chowned_list = []

    def open_dir_then_remove(path: Path, uid: int, gid: int) -> None:
        chowned_list.append(path)

        if path.name == "private1":
            path.chmod(0o755)
        else:
            path.unlink()

    try:
        state_owner_step.give_back_state_result(
            state1, os.getuid(), os.getuid(), os.getgid(), open_dir_then_remove
        )
    finally:
        (state1 / "private1").chmod(0o755)

    assert state1 / "private1" / "file1" in chowned_list


# ------------------------------------------------------------------------------
# The step entry
# ------------------------------------------------------------------------------

def test_the_step_file_holds_one_check_named_state_owner():
    assert [check.name for check in state_owner_step.STEP_LIST] == ["state-owner"]
