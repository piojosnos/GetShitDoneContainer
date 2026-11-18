# ------------------------------------------------------------------------------
# Tests of the Claude managed settings check
# ------------------------------------------------------------------------------
# Real files inside tmp_path.
# ------------------------------------------------------------------------------

import json
import os
from pathlib import Path

import pytest

from helpers import load_agent_check

managed_settings = load_agent_check("claude", "090_managed_settings")


# ------------------------------------------------------------------------------
# Constants and helpers
# ------------------------------------------------------------------------------

def write_managed_settings(settings_file: Path, directory_list: list[str], deny_list: list[str]) -> Path:
    settings_file.write_text(json.dumps({"permissions": {"additionalDirectories": directory_list, "deny": deny_list}}))

    return settings_file


def deny_entry_list(config_dir: Path) -> list[str]:
    return [f"Edit(/{config_dir}/skills/**)"]


# ------------------------------------------------------------------------------
# Managed settings
# ------------------------------------------------------------------------------

def test_managed_settings_result_passes_for_the_clone_and_the_one_deny_entry(tmp_path):
    config1 = tmp_path / "state1" / "agent1"
    settings1 = write_managed_settings(tmp_path / "settings1.json", [str(tmp_path / "clone1")], deny_entry_list(config1))

    result = managed_settings.managed_settings_result(settings1, config1, tmp_path / "clone1")

    assert result.passed


def test_managed_settings_result_fails_for_an_extra_or_missing_deny_entry(tmp_path):
    config1 = tmp_path / "state1" / "agent1"
    clone1 = tmp_path / "clone1"
    extra1 = write_managed_settings(tmp_path / "extra1.json", [str(clone1)], deny_entry_list(config1) + ["Edit(//x)"])
    short1 = write_managed_settings(tmp_path / "short1.json", [str(clone1)], [])

    assert not managed_settings.managed_settings_result(extra1, config1, clone1).passed
    assert not managed_settings.managed_settings_result(short1, config1, clone1).passed


def test_managed_settings_result_fails_for_a_second_directory(tmp_path):
    config1 = tmp_path / "state1" / "agent1"
    clone1 = tmp_path / "clone1"
    two1 = write_managed_settings(tmp_path / "two1.json", [str(clone1), "/etc"], deny_entry_list(config1))

    result = managed_settings.managed_settings_result(two1, config1, clone1)

    assert not result.passed
    assert "additionalDirectories" in result.detail


def test_managed_settings_result_fails_for_text_that_is_not_json_and_for_a_missing_file(tmp_path):
    text1 = tmp_path / "text1.json"
    text1.write_text("not json {")
    missing1 = tmp_path / "missing1.json"

    text_result = managed_settings.managed_settings_result(text1, tmp_path / "config1", tmp_path / "clone1")
    missing_result = managed_settings.managed_settings_result(missing1, tmp_path / "config1", tmp_path / "clone1")

    assert not text_result.passed
    assert text_result.detail == f"{text1} is not valid JSON"
    assert "sbx-upgrade" in text_result.hint
    assert not missing_result.passed
    assert missing_result.detail == f"{missing1} is missing"
    assert "sbx-upgrade" in missing_result.hint


@pytest.mark.skipif(os.getuid() == 0, reason="root can read a mode 000 file")
def test_managed_settings_result_reports_an_unreadable_file_as_not_valid_json(tmp_path):
    locked1 = tmp_path / "locked1.json"
    locked1.write_text("{}")
    locked1.chmod(0o000)

    try:
        result = managed_settings.managed_settings_result(locked1, tmp_path / "config1", tmp_path / "clone1")
    finally:
        locked1.chmod(0o644)

    assert not result.passed
    assert result.detail == f"{locked1} is not valid JSON"


def test_managed_settings_result_fails_for_json_that_is_not_an_object(tmp_path):
    list1 = tmp_path / "list1.json"
    list1.write_text("[1]")

    result = managed_settings.managed_settings_result(list1, tmp_path / "config1", tmp_path / "clone1")

    assert not result.passed
