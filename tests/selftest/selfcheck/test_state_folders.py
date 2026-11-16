# ------------------------------------------------------------------------------
# Tests of the state folder checks
# ------------------------------------------------------------------------------
# The folders exist and a file can be made in the state folder.
# ------------------------------------------------------------------------------

import os
from pathlib import Path

import pytest

import hints
from helpers import load_shared_check

state_folders = load_shared_check("030_state_folders")


# ------------------------------------------------------------------------------
# Constants and helpers
# ------------------------------------------------------------------------------

def make_state_folders(state1: Path, name_list: list[str]) -> None:
    for name in name_list:
        (state1 / name).mkdir(parents=True)


# ------------------------------------------------------------------------------
# State folders and writable
# ------------------------------------------------------------------------------

def test_state_folders_pass_when_base_and_extra_folders_exist(tmp_path):
    state1 = tmp_path / "state1"
    make_state_folders(state1, ["shell", "gh", "git", "cache/npm", "m2"])

    result = state_folders.state_folders_result(state1, "cache/npm m2")

    assert result.passed


def test_state_folders_fail_naming_the_missing_folder(tmp_path):
    state1 = tmp_path / "state1"
    make_state_folders(state1, ["shell", "gh", "git", "cache/npm"])

    result = state_folders.state_folders_result(state1, "cache/npm m2")

    assert not result.passed
    assert "m2" in result.detail
    assert "cache/npm" not in result.detail
    assert result.hint == hints.init_hint()
    assert "sbx-init" in result.hint


def test_state_writable_passes_and_leaves_the_folder_empty(tmp_path):
    state1 = tmp_path / "state1"
    state1.mkdir()

    result = state_folders.state_writable_result(state1)

    assert result.passed
    assert list(state1.iterdir()) == []


@pytest.mark.skipif(os.getuid() == 0, reason="root can write to a read-only folder")
def test_state_writable_fails_for_a_read_only_folder(tmp_path, restorable_mode):
    state1 = tmp_path / "state1"
    state1.mkdir()
    restorable_mode(state1, 0o555)

    result = state_folders.state_writable_result(state1)

    assert not result.passed
    assert "on the Mac run: sbx-stop" in result.hint


def test_state_writable_fails_for_a_missing_folder(tmp_path):
    result = state_folders.state_writable_result(tmp_path / "state1")

    assert not result.passed
