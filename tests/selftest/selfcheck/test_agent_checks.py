# Tests of the agent checks and the generic helpers they stand on. They run on
# real files and real links inside tmp_path: a fake config folder state1/agent1,
# a fake clone best-practices next to state1, and links made with the same
# relative targets as sbx-link-bundle. No login file is ever read; a planted
# token must show up nowhere in a result.

import json
import os
from pathlib import Path

import pytest

import sbx_selfcheck

GSD_PIN1 = "1.15.0"
TOKEN_TEXT1 = "token1"
RULES_LINK_TEXT = "../../best-practices/rules"
SKILL_LINK_TEXT_TEMPLATE = "../../../best-practices/skills/{name}"
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


def write_gsd_pin(folder: Path, version: str = GSD_PIN1) -> Path:
    versions_file = folder / "versions1.env"
    versions_file.write_text(f"GSD_CORE_VERSION={version}\n")

    return versions_file


def write_synced_version(config_dir: Path, version: str) -> None:
    version_file = config_dir / "gsd-core" / "VERSION"
    version_file.parent.mkdir(parents=True, exist_ok=True)
    version_file.write_text(version + "\n")


def make_bundle_tree(base_dir: Path, skill_name_list: list[str], links_rules: bool) -> tuple[Path, Path]:
    config_dir = base_dir / "state1" / "agent1"
    clone_dir = base_dir / "best-practices"
    (config_dir / "skills").mkdir(parents=True)
    (clone_dir / "rules").mkdir(parents=True)
    (clone_dir / "skills").mkdir()

    if links_rules:
        os.symlink(RULES_LINK_TEXT, config_dir / "rules")

    for skill_name in skill_name_list:
        (clone_dir / "skills" / skill_name).mkdir()
        os.symlink(SKILL_LINK_TEXT_TEMPLATE.format(name=skill_name), config_dir / "skills" / skill_name)

    (config_dir / ".best-practices-skills").write_text("".join([name + "\n" for name in skill_name_list]))

    return config_dir, clone_dir


def write_managed_settings(settings_file: Path, directory_list: list[str], deny_list: list[str]) -> Path:
    settings_file.write_text(json.dumps({"permissions": {"additionalDirectories": directory_list, "deny": deny_list}}))

    return settings_file


def deny_entry_list(config_dir: Path) -> list[str]:
    return [f"Edit(/{config_dir}/.best-practices-skills)", f"Edit(/{config_dir}/skills/**)"]


def test_login_file_result_passes_for_a_non_empty_file_and_never_shows_its_text(tmp_path):
    login_file1 = tmp_path / "login1.json"
    login_file1.write_text('{"fake":"' + TOKEN_TEXT1 + '"}')

    result = sbx_selfcheck.login_file_result(login_file1, "hint1")

    assert result.passed
    assert str(login_file1) in result.detail
    assert TOKEN_TEXT1 not in result.detail + result.hint


def test_login_file_result_fails_with_the_hint_for_an_empty_or_missing_file(tmp_path):
    empty_file1 = tmp_path / "empty1.json"
    empty_file1.write_text("")

    empty_result = sbx_selfcheck.login_file_result(empty_file1, "hint1")
    missing_result = sbx_selfcheck.login_file_result(tmp_path / "missing1.json", "hint1")

    assert not empty_result.passed
    assert empty_result.hint == "hint1"
    assert not missing_result.passed
    assert missing_result.hint == "hint1"


def test_login_file_result_never_opens_the_file(tmp_path):
    login_dir1 = tmp_path / "login1.json"
    login_dir1.mkdir()
    (login_dir1 / "inner1").write_text(TOKEN_TEXT1)

    result = sbx_selfcheck.login_file_result(login_dir1, "hint1")

    assert not result.passed
    assert TOKEN_TEXT1 not in result.detail + result.hint


def test_gsd_synced_result_passes_when_the_synced_version_is_the_pin(tmp_path):
    config1 = tmp_path / "config1"
    write_synced_version(config1, GSD_PIN1)

    result = sbx_selfcheck.gsd_synced_result(config1, write_gsd_pin(tmp_path))

    assert result.passed
    assert GSD_PIN1 in result.detail


def test_gsd_synced_result_fails_for_another_version_and_for_a_missing_file(tmp_path, monkeypatch):
    monkeypatch.setenv("SBX_NAME", "name1")
    versions1 = write_gsd_pin(tmp_path)
    config1 = tmp_path / "config1"
    config2 = tmp_path / "config2"
    write_synced_version(config1, "1.14.0")
    config2.mkdir()

    other_result = sbx_selfcheck.gsd_synced_result(config1, versions1)
    missing_result = sbx_selfcheck.gsd_synced_result(config2, versions1)

    assert not other_result.passed
    assert "1.14.0" in other_result.detail
    assert "on the Mac run: sbx-stop name1" in other_result.hint
    assert not missing_result.passed
    assert "on the Mac run: sbx-stop name1" in missing_result.hint


def test_gsd_synced_result_fails_when_the_pin_is_missing(tmp_path):
    versions1 = tmp_path / "versions1.env"
    versions1.write_text("NODE_VERSION=1\n")
    config1 = tmp_path / "config1"
    write_synced_version(config1, GSD_PIN1)

    result = sbx_selfcheck.gsd_synced_result(config1, versions1)

    assert not result.passed
    assert "GSD_CORE_VERSION" in result.detail


def test_bundle_links_result_passes_on_a_linked_tree_with_the_list_in_any_order(tmp_path):
    config1, clone1 = make_bundle_tree(tmp_path, ["skill-a", "skill-b"], True)
    (config1 / ".best-practices-skills").write_text("skill-b\nskill-a\n")

    result = sbx_selfcheck.bundle_links_result(config1, clone1, True)

    assert result.passed
    assert "2 skills linked" in result.detail
    assert "rules linked" in result.detail


def test_bundle_links_result_fails_naming_a_missing_skill_link(tmp_path):
    config1, clone1 = make_bundle_tree(tmp_path, ["skill-a", "skill-b"], True)
    (config1 / "skills" / "skill-b").unlink()

    result = sbx_selfcheck.bundle_links_result(config1, clone1, True)

    assert not result.passed
    assert "skill-b" in result.detail
    assert "skill-a" not in result.detail
    assert "sbx-bundle-clone" in result.hint


def test_bundle_links_result_fails_for_a_skill_link_with_another_target(tmp_path):
    config1, clone1 = make_bundle_tree(tmp_path, ["skill-a"], True)
    (config1 / "skills" / "skill-a").unlink()
    os.symlink(str(clone1 / "skills" / "skill-a"), config1 / "skills" / "skill-a")

    result = sbx_selfcheck.bundle_links_result(config1, clone1, True)

    assert not result.passed
    assert "skill-a" in result.detail


def test_bundle_links_result_fails_for_a_copy_in_place_of_a_skill_link(tmp_path):
    config1, clone1 = make_bundle_tree(tmp_path, ["skill-a"], True)
    (config1 / "skills" / "skill-a").unlink()
    (config1 / "skills" / "skill-a").mkdir()

    result = sbx_selfcheck.bundle_links_result(config1, clone1, True)

    assert not result.passed
    assert "skill-a" in result.detail


def test_bundle_links_result_fails_for_a_rules_link_with_another_target(tmp_path):
    config1, clone1 = make_bundle_tree(tmp_path, ["skill-a"], True)
    (tmp_path / "other1").mkdir()
    (config1 / "rules").unlink()
    os.symlink("../../other1", config1 / "rules")

    result = sbx_selfcheck.bundle_links_result(config1, clone1, True)

    assert not result.passed
    assert "rules" in result.detail


def test_bundle_links_result_fails_for_rules_that_is_not_a_link(tmp_path):
    config1, clone1 = make_bundle_tree(tmp_path, ["skill-a"], False)
    (config1 / "rules").mkdir()

    result = sbx_selfcheck.bundle_links_result(config1, clone1, True)

    assert not result.passed
    assert "rules" in result.detail


def test_bundle_links_result_fails_when_the_list_misses_a_skill(tmp_path):
    config1, clone1 = make_bundle_tree(tmp_path, ["skill-a", "skill-b"], True)
    (config1 / ".best-practices-skills").write_text("skill-a\n")

    result = sbx_selfcheck.bundle_links_result(config1, clone1, True)

    assert not result.passed
    assert "skill-b" in result.detail


def test_bundle_links_result_fails_when_the_list_is_missing(tmp_path):
    config1, clone1 = make_bundle_tree(tmp_path, ["skill-a"], True)
    (config1 / ".best-practices-skills").unlink()

    result = sbx_selfcheck.bundle_links_result(config1, clone1, True)

    assert not result.passed
    assert ".best-practices-skills" in result.detail


def test_bundle_links_result_says_there_is_no_clone_when_the_folder_the_mode_needs_is_absent(tmp_path):
    config1 = tmp_path / "state1" / "agent1"
    config1.mkdir(parents=True)
    clone1 = tmp_path / "best-practices"
    (clone1 / "rules").mkdir(parents=True)

    skills_result = sbx_selfcheck.bundle_links_result(config1, clone1, False)
    rules_result = sbx_selfcheck.bundle_links_result(config1, tmp_path / "missing1", True)

    assert not skills_result.passed
    assert "no clone" in skills_result.detail
    assert "sbx-bundle-clone" in skills_result.hint
    assert not rules_result.passed
    assert "no clone" in rules_result.detail


def test_bundle_links_result_without_rules_mode_passes_on_a_tree_with_no_rules_link(tmp_path):
    config1, clone1 = make_bundle_tree(tmp_path, ["skill-a", "skill-b"], False)

    result = sbx_selfcheck.bundle_links_result(config1, clone1, False)

    assert result.passed
    assert "2 skills linked" in result.detail
    assert "rules" not in result.detail


def test_home_links_result_passes_when_each_link_holds_its_target_text(tmp_path):
    target1 = tmp_path / "target1"
    target1.mkdir()
    link1 = tmp_path / "link1"
    link2 = tmp_path / "link2"
    os.symlink(str(target1), link1)
    os.symlink(str(target1), link2)

    result = sbx_selfcheck.home_links_result([(link1, target1), (link2, target1)])

    assert result.passed
    assert str(link1) in result.detail
    assert str(link2) in result.detail


def test_home_links_result_fails_for_a_folder_in_place_of_a_link_and_for_another_target(tmp_path, monkeypatch):
    monkeypatch.setenv("SBX_NAME", "name1")
    target1 = tmp_path / "target1"
    target2 = tmp_path / "target2"
    target1.mkdir()
    target2.mkdir()
    folder1 = tmp_path / "folder1"
    folder1.mkdir()
    link2 = tmp_path / "link2"
    os.symlink(str(target2), link2)

    folder_result = sbx_selfcheck.home_links_result([(folder1, target1)])
    target_result = sbx_selfcheck.home_links_result([(link2, target1)])

    assert not folder_result.passed
    assert str(folder1) in folder_result.detail
    assert not target_result.passed
    assert str(link2) in target_result.detail
    assert "sbx-upgrade name1" in target_result.hint


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


def test_the_claude_check_names_are_the_twelve_in_order(agent_module):
    claude = agent_module("claude")

    assert [check.name for check in claude.CHECK_LIST] == CLAUDE_CHECK_NAME_LIST


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
    environment = {"PATH": f"{folder}{os.pathsep}{os.environ['PATH']}", "HOME": str(folder / "home1")}

    if with_config_dir:
        environment["CURSOR_CONFIG_DIR"] = str(folder / "state1" / "cursor")

    return environment


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


def test_self_update_result_fails_for_another_channel_bad_text_and_a_missing_file(agent_module, tmp_path, monkeypatch):
    monkeypatch.setenv("SBX_NAME", "name1")
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
        assert "on the Mac run: sbx-stop name1" in result.hint


def test_the_cursor_check_names_are_the_ten_in_order(agent_module):
    cursor = agent_module("cursor")

    assert [check.name for check in cursor.CHECK_LIST] == CURSOR_CHECK_NAME_LIST
