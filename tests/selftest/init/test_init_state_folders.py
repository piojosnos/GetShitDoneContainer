# ------------------------------------------------------------------------------
# Tests of the state folders step
# ------------------------------------------------------------------------------
# The step makes the base folders and the ones SBX_STATE_DIRS adds, keeps what
# exists and refuses names that leave the state folder.
# ------------------------------------------------------------------------------

import os

import pytest

import hints
import paths
from init_helpers import REPO_DIR, load_step

state_folders_step = load_step(REPO_DIR / "base" / "init" / "steps" / "010_state_folders.py")
state_folders_check = load_step(REPO_DIR / "base" / "selfcheck" / "checks" / "030_state_folders.py")


# ------------------------------------------------------------------------------
# Making the folders
# ------------------------------------------------------------------------------

@pytest.mark.parametrize("state_dirs_text", ["", "   "])
def test_an_unset_or_empty_list_makes_only_the_base_folders_and_passes(tmp_path, state_dirs_text):
    state1 = tmp_path / "state1"
    state1.mkdir()

    result = state_folders_step.make_state_folders_result(state1, state_dirs_text)

    assert result.passed
    assert result.detail == f"shell, gh, git exist under {state1}"
    assert sorted(path.name for path in state1.iterdir()) == ["gh", "git", "shell"]


def test_the_listed_folders_are_made_with_their_parents(tmp_path):
    state1 = tmp_path / "state1"
    state1.mkdir()

    result = state_folders_step.make_state_folders_result(state1, "cache/npm claude")

    assert result.passed
    assert (state1 / "cache" / "npm").is_dir()
    assert (state1 / "claude").is_dir()


def test_existing_folders_are_kept_and_count_as_made(tmp_path):
    state1 = tmp_path / "state1"
    (state1 / "gh").mkdir(parents=True)
    (state1 / "gh" / "file1").write_text("text1")

    result = state_folders_step.make_state_folders_result(state1, "")

    assert result.passed
    assert (state1 / "gh" / "file1").read_text() == "text1"


def test_a_name_listed_twice_is_made_once_and_listed_once(tmp_path):
    state1 = tmp_path / "state1"
    state1.mkdir()

    result = state_folders_step.make_state_folders_result(state1, "claude claude")

    assert result.passed
    assert result.detail == f"shell, gh, git, claude exist under {state1}"


def test_the_init_step_and_the_check_make_and_verify_the_same_base_list(tmp_path):
    state1 = tmp_path / "state1"
    state1.mkdir()

    state_folders_step.make_state_folders_result(state1, "claude")

    assert paths.BASE_STATE_DIR_LIST == ["shell", "gh", "git"]
    assert state_folders_check.state_folders_result(state1, "claude").passed


# ------------------------------------------------------------------------------
# Refusals and failures
# ------------------------------------------------------------------------------

def test_a_regular_file_where_a_state_folder_belongs_fails_naming_it(tmp_path):
    state1 = tmp_path / "state1"
    state1.mkdir()
    (state1 / "gh").write_text("text1")

    result = state_folders_step.make_state_folders_result(state1, "")

    assert not result.passed
    assert str(state1 / "gh") in result.detail
    assert (state1 / "gh").read_text() == "text1"


@pytest.mark.parametrize("name", ["/abs1", "a/../b", ".."])
def test_an_absolute_name_or_one_with_a_dot_dot_part_fails_before_any_folder_is_made(tmp_path, name):
    state1 = tmp_path / "state1"
    state1.mkdir()

    result = state_folders_step.make_state_folders_result(state1, f"claude {name}")

    assert not result.passed
    assert f"'{name}'" in result.detail
    assert list(state1.iterdir()) == []
    assert not (tmp_path / "b").exists()


@pytest.mark.skipif(os.getuid() == 0, reason="root can write to a read-only folder")
def test_a_read_only_state_folder_fails_with_the_writable_fix(tmp_path):
    state1 = tmp_path / "state1"
    state1.mkdir()
    state1.chmod(0o555)

    try:
        result = state_folders_step.make_state_folders_result(state1, "")
    finally:
        state1.chmod(0o755)

    assert not result.passed
    assert "writable by your Mac user" in result.hint


def test_the_check_fix_line_points_at_sbx_init(tmp_path):
    result = state_folders_check.state_folders_result(tmp_path / "state1", "")

    assert not result.passed
    assert result.hint == hints.init_hint()
