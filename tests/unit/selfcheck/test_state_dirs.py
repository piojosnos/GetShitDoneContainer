# ------------------------------------------------------------------------------
# Tests of the state directory checks
# ------------------------------------------------------------------------------
# The directories exist and a file can be made in the state directory.
# ------------------------------------------------------------------------------

import os
from pathlib import Path

import pytest

import hints
from helpers import load_shared_check

state_dirs = load_shared_check("030_state_dirs")


# ------------------------------------------------------------------------------
# Constants and helpers
# ------------------------------------------------------------------------------

def make_state_dirs(state1: Path, name_list: list[str]) -> None:
    for name in name_list:
        (state1 / name).mkdir(parents=True)


# ------------------------------------------------------------------------------
# State directories and writable
# ------------------------------------------------------------------------------

def test_state_dirs_pass_when_base_and_extra_dirs_exist(tmp_path):
    state1 = tmp_path / "state1"
    make_state_dirs(state1, ["shell", "gh", "git", "cache/npm", "m2"])

    result = state_dirs.state_dirs_result(state1, "cache/npm m2")

    assert result.passed


def test_a_name_listed_twice_is_checked_once_and_listed_once(tmp_path):
    state1 = tmp_path / "state1"
    make_state_dirs(state1, ["shell", "gh", "git", "claude"])

    result = state_dirs.state_dirs_result(state1, "claude claude")

    assert result.passed
    assert result.detail == f"shell, gh, git, claude exist under {state1}"


def test_state_dirs_fail_naming_the_missing_dir(tmp_path):
    state1 = tmp_path / "state1"
    make_state_dirs(state1, ["shell", "gh", "git", "cache/npm"])

    result = state_dirs.state_dirs_result(state1, "cache/npm m2")

    assert not result.passed
    assert "m2" in result.detail
    assert "cache/npm" not in result.detail
    assert result.hint == hints.init_hint()
    assert "sbx-init" in result.hint


def test_state_writable_passes_and_leaves_the_dir_empty(tmp_path):
    state1 = tmp_path / "state1"
    state1.mkdir()

    result = state_dirs.state_writable_result(state1)

    assert result.passed
    assert list(state1.iterdir()) == []


@pytest.mark.skipif(os.getuid() == 0, reason="root can write to a read-only directory")
def test_state_writable_fails_for_a_read_only_dir(tmp_path, restorable_mode):
    state1 = tmp_path / "state1"
    state1.mkdir()
    restorable_mode(state1, 0o555)

    result = state_dirs.state_writable_result(state1)

    assert not result.passed
    assert result.hint == hints.state_writable_hint()


def test_state_writable_fails_for_a_missing_dir(tmp_path):
    result = state_dirs.state_writable_result(tmp_path / "state1")

    assert not result.passed
