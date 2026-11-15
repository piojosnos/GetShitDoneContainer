# ------------------------------------------------------------------------------
# Tests of the Claude and Cursor check files
# ------------------------------------------------------------------------------

import json
import os
from pathlib import Path

import pytest

import hints


# ------------------------------------------------------------------------------
# Constants and helpers
# ------------------------------------------------------------------------------

CURSOR_CHECK_NAME_LIST = [
    "tool-cursor-agent",
    "cursor-env",
    "cursor-home-links",
    "cursor-self-update-off",
    "cursor-credentials",
    "cursor-gsd-synced",
    "cursor-bundle-links",
    "cursor-wrappers",
    "cursor-image-paths-protected",
    "cursor-versions-line",
]


CLAUDE_CHECK_NAME_LIST = [
    "tool-claude",
    "tool-ccusage",
    "claude-env",
    "claude-home-links",
    "claude-no-home-copy",
    "claude-credentials",
    "claude-gsd-synced",
    "claude-bundle-links",
    "claude-wrappers",
    "claude-managed-settings",
    "claude-image-paths-protected",
    "claude-versions-line",
]


def write_managed_settings(settings_file: Path, directory_list: list[str], deny_list: list[str]) -> Path:
    settings_file.write_text(json.dumps({"permissions": {"additionalDirectories": directory_list, "deny": deny_list}}))

    return settings_file


def deny_entry_list(config_dir: Path) -> list[str]:
    return [f"Edit(/{config_dir}/.best-practices-skills)", f"Edit(/{config_dir}/skills/**)"]


# ------------------------------------------------------------------------------
# Claude checks
# ------------------------------------------------------------------------------

def test_managed_settings_result_passes_for_the_clone_and_the_two_deny_entries(agent_module, tmp_path):
    claude = agent_module("claude")
    config1 = tmp_path / "state1" / "agent1"
    settings1 = write_managed_settings(tmp_path / "settings1.json", [str(tmp_path / "clone1")], deny_entry_list(config1))

    result = claude.managed_settings_result(settings1, tmp_path / "clone1", config1)

    assert result.passed


def test_managed_settings_result_fails_for_an_extra_or_missing_deny_entry(agent_module, tmp_path):
    claude = agent_module("claude")
    config1 = tmp_path / "state1" / "agent1"
    clone1 = tmp_path / "clone1"
    extra1 = write_managed_settings(tmp_path / "extra1.json", [str(clone1)], deny_entry_list(config1) + ["Edit(//x)"])
    short1 = write_managed_settings(tmp_path / "short1.json", [str(clone1)], deny_entry_list(config1)[:1])

    assert not claude.managed_settings_result(extra1, clone1, config1).passed
    assert not claude.managed_settings_result(short1, clone1, config1).passed


def test_managed_settings_result_fails_for_a_second_directory(agent_module, tmp_path):
    claude = agent_module("claude")
    config1 = tmp_path / "state1" / "agent1"
    clone1 = tmp_path / "clone1"
    two1 = write_managed_settings(tmp_path / "two1.json", [str(clone1), "/etc"], deny_entry_list(config1))

    result = claude.managed_settings_result(two1, clone1, config1)

    assert not result.passed
    assert "additionalDirectories" in result.detail


def test_managed_settings_result_fails_for_text_that_is_not_json_and_for_a_missing_file(agent_module, tmp_path):
    claude = agent_module("claude")
    text1 = tmp_path / "text1.json"
    text1.write_text("not json {")
    missing1 = tmp_path / "missing1.json"

    text_result = claude.managed_settings_result(text1, tmp_path / "clone1", tmp_path / "config1")
    missing_result = claude.managed_settings_result(missing1, tmp_path / "clone1", tmp_path / "config1")

    assert not text_result.passed
    assert text_result.detail == f"{text1} is not valid JSON"
    assert "sbx-upgrade" in text_result.hint
    assert not missing_result.passed
    assert missing_result.detail == f"{missing1} is missing"
    assert "sbx-upgrade" in missing_result.hint


@pytest.mark.skipif(os.getuid() == 0, reason="root can read a mode 000 file")
def test_managed_settings_result_reports_an_unreadable_file_as_not_valid_json(agent_module, tmp_path):
    claude = agent_module("claude")
    locked1 = tmp_path / "locked1.json"
    locked1.write_text("{}")
    locked1.chmod(0o000)

    try:
        result = claude.managed_settings_result(locked1, tmp_path / "clone1", tmp_path / "config1")
    finally:
        locked1.chmod(0o644)

    assert not result.passed
    assert result.detail == f"{locked1} is not valid JSON"


def test_managed_settings_result_fails_for_json_that_is_not_an_object(agent_module, tmp_path):
    claude = agent_module("claude")
    list1 = tmp_path / "list1.json"
    list1.write_text("[1]")

    result = claude.managed_settings_result(list1, tmp_path / "clone1", tmp_path / "config1")

    assert not result.passed


def test_the_claude_check_names_are_the_twelve_in_order(agent_module, check_name_list_of):
    claude = agent_module("claude")

    assert check_name_list_of(claude.CHECK_LIST) == CLAUDE_CHECK_NAME_LIST


def test_claude_no_home_copy_passes_when_no_copy_exists_and_fails_naming_each_copy(agent_module, tmp_path):
    claude = agent_module("claude")
    copy_dir1 = tmp_path / "share1"
    copy_link1 = tmp_path / "bin1"

    passing_result = claude.no_home_copy_result([copy_dir1, copy_link1])
    copy_dir1.mkdir()
    os.symlink("nowhere1", copy_link1)
    failing_result = claude.no_home_copy_result([copy_dir1, copy_link1])

    assert passing_result.passed
    assert not failing_result.passed
    assert str(copy_dir1) in failing_result.detail
    assert str(copy_link1) in failing_result.detail
    assert "remove ~/.local/share/claude and ~/.local/bin/claude" in failing_result.hint


# ------------------------------------------------------------------------------
# Cursor checks
# ------------------------------------------------------------------------------

def write_cursor_stand_in(folder: Path, home_record_file: Path) -> None:
    stand_in = folder / "cursor-agent"
    stand_in.write_text(
        "#!/bin/sh\n"
        f'printf \'%s\' "$HOME" > "{home_record_file}"\n'
        'echo "$HOME" > "$HOME/cli-config.json"\n'
        'if [ -z "${CURSOR_CONFIG_DIR+x}" ]; then echo v1; else echo config-dir-was-set; fi\n'
    )
    stand_in.chmod(0o755)


def cursor_environment(folder: Path, with_config_dir: bool) -> dict[str, str]:
    environment_map = {"PATH": f"{folder}{os.pathsep}{os.environ['PATH']}", "HOME": str(folder / "home1")}

    if with_config_dir:
        environment_map["CURSOR_CONFIG_DIR"] = str(folder / "state1" / "cursor")

    return environment_map


def test_cursor_version_result_runs_the_cli_with_a_throwaway_home_that_is_gone_afterwards(agent_module, tmp_path):
    cursor = agent_module("cursor")
    home_record1 = tmp_path / "home-record1"
    write_cursor_stand_in(tmp_path, home_record1)
    environment1 = cursor_environment(tmp_path, False)

    result = cursor.cursor_version_result("v1", environment1)

    seen_home = Path(home_record1.read_text())
    assert result.passed
    assert str(seen_home) != environment1["HOME"]
    assert not seen_home.exists()
    assert not (tmp_path / "home1" / "cli-config.json").exists()


def test_cursor_version_result_hides_the_config_folder_variable_from_the_cli(agent_module, tmp_path):
    cursor = agent_module("cursor")
    write_cursor_stand_in(tmp_path, tmp_path / "home-record1")
    environment1 = cursor_environment(tmp_path, True)

    result = cursor.cursor_version_result("v1", environment1)

    assert result.passed
    assert environment1["CURSOR_CONFIG_DIR"] == str(tmp_path / "state1" / "cursor")
    assert not (tmp_path / "state1").exists()


def test_cursor_version_result_fails_for_another_version(agent_module, tmp_path):
    cursor = agent_module("cursor")
    home_record1 = tmp_path / "home-record1"
    write_cursor_stand_in(tmp_path, home_record1)

    result = cursor.cursor_version_result("v2", cursor_environment(tmp_path, False))

    assert not result.passed
    assert "v1" in result.detail
    assert not Path(home_record1.read_text()).exists()


def test_self_update_result_passes_for_the_static_channel_and_names_no_other_key(agent_module, tmp_path):
    cursor = agent_module("cursor")
    config_file1 = tmp_path / "cli-config1.json"
    config_file1.write_text(json.dumps({"channel": "static", "other1": 1}))

    result = cursor.self_update_result(config_file1)

    assert result.passed
    assert "static" in result.detail
    assert "other1" not in result.detail + result.hint


def test_self_update_result_fails_for_another_channel_bad_text_and_a_missing_file(agent_module, tmp_path):
    cursor = agent_module("cursor")
    stable1 = tmp_path / "stable1.json"
    stable1.write_text(json.dumps({"channel": "stable", "other1": 1}))
    text1 = tmp_path / "text1.json"
    text1.write_text("not json {")
    list1 = tmp_path / "list1.json"
    list1.write_text("[1]")

    stable_result = cursor.self_update_result(stable1)
    text_result = cursor.self_update_result(text1)
    list_result = cursor.self_update_result(list1)
    missing_result = cursor.self_update_result(tmp_path / "missing1.json")

    assert "stable" in stable_result.detail
    assert "other1" not in stable_result.detail

    for result in [stable_result, text_result, list_result, missing_result]:
        assert not result.passed
        assert result.hint.startswith(hints.restart_hint())


def test_the_cursor_check_names_are_the_ten_in_order(agent_module, check_name_list_of):
    cursor = agent_module("cursor")

    assert check_name_list_of(cursor.CHECK_LIST) == CURSOR_CHECK_NAME_LIST
