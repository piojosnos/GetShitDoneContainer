# ------------------------------------------------------------------------------
# Tests of the Cursor self-update step
# ------------------------------------------------------------------------------
# Real files inside tmp_path; a file the step refuses must stay byte for byte as
# it was, with no temp file beside it.
# ------------------------------------------------------------------------------

import json
import os

import pytest

import cursor_shared
import hints
from init_helpers import REPO_DIR, load_step

self_update_step = load_step(REPO_DIR / "cursor" / "init" / "060_self_update_off.py")
self_update_check = load_step(REPO_DIR / "cursor" / "selfcheck" / "050_self_update_off.py")
gsd_sync_step = load_step(REPO_DIR / "cursor" / "init" / "050_gsd_sync.py")


# ------------------------------------------------------------------------------
# Setting the channel
# ------------------------------------------------------------------------------

def test_a_missing_file_is_written_with_the_static_channel(tmp_path):
    config_file1 = tmp_path / "config1" / "cli-config.json"

    result = self_update_step.static_channel_result(config_file1)

    assert result.passed
    assert str(config_file1) in result.detail
    assert json.loads(config_file1.read_text()) == {"channel": "static"}


def test_an_empty_file_is_written_like_a_missing_one(tmp_path):
    config_file1 = tmp_path / "cli-config.json"
    config_file1.write_text("")

    result = self_update_step.static_channel_result(config_file1)

    assert result.passed
    assert json.loads(config_file1.read_text()) == {"channel": "static"}


def test_another_channel_becomes_static_and_every_other_key_stays(tmp_path):
    config_file1 = tmp_path / "cli-config.json"
    config_file1.write_text(json.dumps({"channel": "lab", "key1": 1, "key2": {"nested1": [1, 2]}}))

    result = self_update_step.static_channel_result(config_file1)

    assert result.passed
    assert json.loads(config_file1.read_text()) == {"channel": "static", "key1": 1, "key2": {"nested1": [1, 2]}}


def test_an_already_static_file_passes_with_the_same_content(tmp_path):
    config_file1 = tmp_path / "cli-config.json"
    config_file1.write_text(json.dumps({"key1": 1, "channel": "static"}))

    result = self_update_step.static_channel_result(config_file1)

    assert result.passed
    assert json.loads(config_file1.read_text()) == {"key1": 1, "channel": "static"}
    assert [path.name for path in tmp_path.iterdir()] == ["cli-config.json"]


def test_a_missing_config_dir_is_made_first(tmp_path):
    config_file1 = tmp_path / "deep1" / "deeper1" / "cli-config.json"

    result = self_update_step.static_channel_result(config_file1)

    assert result.passed
    assert config_file1.is_file()


# ------------------------------------------------------------------------------
# Files the step refuses
# ------------------------------------------------------------------------------

@pytest.mark.parametrize(
    ("file_bytes", "problem_text"),
    [
        (b"not json {", "is not valid JSON"),
        (b"[1, 2]", "holds JSON that is not an object"),
        (b'"static"', "holds JSON that is not an object"),
    ],
)
def test_a_file_that_is_not_a_json_object_fails_and_is_left_byte_for_byte(tmp_path, file_bytes, problem_text):
    config_file1 = tmp_path / "cli-config.json"
    config_file1.write_bytes(file_bytes)

    result = self_update_step.static_channel_result(config_file1)

    assert not result.passed
    assert str(config_file1) in result.detail
    assert problem_text in result.detail
    assert "left as it was" in result.detail
    assert result.hint == f"fix or delete {config_file1}, then run sbx-init again"
    assert config_file1.read_bytes() == file_bytes
    assert [path.name for path in tmp_path.iterdir()] == ["cli-config.json"]


def test_a_path_that_cannot_be_read_fails_and_leaves_no_temp_file(tmp_path):
    config_dir1 = tmp_path / "cli-config.json"
    config_dir1.mkdir()

    result = self_update_step.static_channel_result(config_dir1)

    assert not result.passed
    assert str(config_dir1) in result.detail
    assert [path.name for path in tmp_path.iterdir()] == ["cli-config.json"]


def test_a_config_dir_that_cannot_be_made_fails_naming_it(tmp_path):
    blocker1 = tmp_path / "blocker1"
    blocker1.write_text("a file where a directory is needed")

    result = self_update_step.static_channel_result(blocker1 / "cli-config.json")

    assert not result.passed
    assert str(blocker1) in result.detail
    assert result.hint == hints.state_writable_hint()
    assert blocker1.read_text() == "a file where a directory is needed"


@pytest.mark.skipif(os.getuid() == 0, reason="root can write to a read-only directory")
def test_a_config_dir_that_cannot_be_written_fails_with_the_writable_fix(tmp_path):
    config_dir1 = tmp_path / "config1"
    config_dir1.mkdir()
    config_dir1.chmod(0o555)

    try:
        result = self_update_step.static_channel_result(config_dir1 / "cli-config.json")
    finally:
        config_dir1.chmod(0o755)

    assert not result.passed
    assert str(config_dir1 / "cli-config.json") in result.detail
    assert result.hint == hints.state_writable_hint()


# ------------------------------------------------------------------------------
# Step files and the check twin
# ------------------------------------------------------------------------------

def test_the_step_file_holds_one_step_and_reads_the_constant_the_check_reads():
    assert [step.name for step in self_update_step.STEP_LIST] == ["cursor-self-update-off"]
    assert self_update_step.CLI_CONFIG_FILE is cursor_shared.CLI_CONFIG_FILE
    assert self_update_check.CLI_CONFIG_FILE is cursor_shared.CLI_CONFIG_FILE
    assert cursor_shared.CLI_CONFIG_FILE == cursor_shared.AGENT_CONFIG_DIR / "cli-config.json"


def test_the_cursor_gsd_step_file_holds_one_step_named_for_cursor():
    assert [step.name for step in gsd_sync_step.STEP_LIST] == ["cursor-gsd-sync"]
