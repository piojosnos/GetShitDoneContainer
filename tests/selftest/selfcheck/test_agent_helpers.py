# ------------------------------------------------------------------------------
# Tests of the helpers the agent checks share
# ------------------------------------------------------------------------------
# Real files and links inside tmp_path. A planted login token must show up
# nowhere in a result.
# ------------------------------------------------------------------------------

import os
from pathlib import Path

import agent_helpers
import selfcheck_core


def test_versions_line_result_passes_for_the_prefix_and_the_base_text(versions1, line1):
    line1.write_text("tool1 1 | " + selfcheck_core.expected_base_versions_text(versions1) + "\n")

    result = agent_helpers.versions_line_result("tool1 1 | ", line1, versions1)

    assert result.passed


def test_versions_line_result_fails_when_one_field_differs(versions1, line1):
    line1.write_text("tool1 1 | " + selfcheck_core.expected_base_versions_text(versions1).replace("node 24.21.0", "node 24.21.1") + "\n")

    result = agent_helpers.versions_line_result("tool1 1 | ", line1, versions1)

    assert not result.passed
    assert "node 24.21.1" in result.detail
    assert "node 24.21.0" in result.detail
    assert "sbx-upgrade" in result.hint


def test_versions_line_result_fails_when_the_file_holds_two_lines(versions1, line1):
    base_text = selfcheck_core.expected_base_versions_text(versions1)
    line1.write_text("tool1 1 | " + base_text + "\n" + "tool1 1 | " + base_text + "\n")

    assert not agent_helpers.versions_line_result("tool1 1 | ", line1, versions1).passed


def test_versions_line_result_fails_when_the_file_is_missing(tmp_path, versions1):
    result = agent_helpers.versions_line_result("tool1 1 | ", tmp_path / "missing1", versions1)

    assert not result.passed
    assert "missing1" in result.detail


def test_versions_line_result_reports_a_missing_pin(tmp_path, line1):
    empty_versions = tmp_path / "empty1.env"
    empty_versions.write_text("")
    line1.write_text("anything\n")

    result = agent_helpers.versions_line_result("tool1 1 | ", line1, empty_versions)

    assert not result.passed
    assert result.detail.startswith("GSD_CORE_VERSION is not in ")


# ------------------------------------------------------------------------------
# Constants and helpers
# ------------------------------------------------------------------------------

GSD_PIN1 = "1.15.0"
TOKEN_TEXT1 = "token1"
RULES_LINK_TEXT = "../../best-practices/rules"
SKILL_LINK_TEXT_TEMPLATE = "../../../best-practices/skills/{name}"


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

    skill_line_list = []

    for skill_name in skill_name_list:
        skill_line_list.append(skill_name + "\n")

    (config_dir / ".best-practices-skills").write_text("".join(skill_line_list))

    return config_dir, clone_dir


# ------------------------------------------------------------------------------
# Login file and GSD sync
# ------------------------------------------------------------------------------

def test_login_file_result_passes_for_a_non_empty_file_and_never_shows_its_text(tmp_path):
    login_file1 = tmp_path / "login1.json"
    login_file1.write_text('{"fake":"' + TOKEN_TEXT1 + '"}')

    result = agent_helpers.login_file_result(login_file1, "hint1")

    assert result.passed
    assert str(login_file1) in result.detail
    assert TOKEN_TEXT1 not in result.detail + result.hint


def test_login_file_result_fails_with_the_hint_for_an_empty_or_missing_file(tmp_path):
    empty_file1 = tmp_path / "empty1.json"
    empty_file1.write_text("")

    empty_result = agent_helpers.login_file_result(empty_file1, "hint1")
    missing_result = agent_helpers.login_file_result(tmp_path / "missing1.json", "hint1")

    assert not empty_result.passed
    assert empty_result.hint == "hint1"
    assert not missing_result.passed
    assert missing_result.hint == "hint1"


def test_login_file_result_never_opens_the_file(tmp_path):
    login_dir1 = tmp_path / "login1.json"
    login_dir1.mkdir()
    (login_dir1 / "inner1").write_text(TOKEN_TEXT1)

    result = agent_helpers.login_file_result(login_dir1, "hint1")

    assert not result.passed
    assert TOKEN_TEXT1 not in result.detail + result.hint


def test_gsd_synced_result_passes_when_the_synced_version_is_the_pin(tmp_path):
    config1 = tmp_path / "config1"
    write_synced_version(config1, GSD_PIN1)

    result = agent_helpers.gsd_synced_result(config1, write_gsd_pin(tmp_path))

    assert result.passed
    assert GSD_PIN1 in result.detail


def test_gsd_synced_result_fails_for_another_version_and_for_a_missing_file(tmp_path):
    versions1 = write_gsd_pin(tmp_path)
    config1 = tmp_path / "config1"
    config2 = tmp_path / "config2"
    write_synced_version(config1, "1.14.0")
    config2.mkdir()

    other_result = agent_helpers.gsd_synced_result(config1, versions1)
    missing_result = agent_helpers.gsd_synced_result(config2, versions1)

    assert not other_result.passed
    assert "1.14.0" in other_result.detail
    assert other_result.hint.startswith(selfcheck_core.restart_hint())
    assert not missing_result.passed
    assert missing_result.hint.startswith(selfcheck_core.restart_hint())


def test_gsd_synced_result_fails_when_the_pin_is_missing(tmp_path):
    versions1 = tmp_path / "versions1.env"
    versions1.write_text("NODE_VERSION=1\n")
    config1 = tmp_path / "config1"
    write_synced_version(config1, GSD_PIN1)

    result = agent_helpers.gsd_synced_result(config1, versions1)

    assert not result.passed
    assert "GSD_CORE_VERSION" in result.detail


# ------------------------------------------------------------------------------
# Bundle links
# ------------------------------------------------------------------------------

def test_bundle_links_result_passes_on_a_linked_tree_with_the_list_in_any_order(tmp_path):
    config1, clone1 = make_bundle_tree(tmp_path, ["skill-a", "skill-b"], True)
    (config1 / ".best-practices-skills").write_text("skill-b\nskill-a\n")

    result = agent_helpers.bundle_links_result(config1, clone1, True)

    assert result.passed
    assert "2 skills linked" in result.detail
    assert "rules linked" in result.detail


def test_bundle_links_result_fails_naming_a_missing_skill_link(tmp_path):
    config1, clone1 = make_bundle_tree(tmp_path, ["skill-a", "skill-b"], True)
    (config1 / "skills" / "skill-b").unlink()

    result = agent_helpers.bundle_links_result(config1, clone1, True)

    assert not result.passed
    assert "skill-b" in result.detail
    assert "skill-a" not in result.detail
    assert "sbx-bundle-clone" in result.hint


def test_bundle_links_result_fails_for_a_skill_link_with_another_target(tmp_path):
    config1, clone1 = make_bundle_tree(tmp_path, ["skill-a"], True)
    (config1 / "skills" / "skill-a").unlink()
    os.symlink(str(clone1 / "skills" / "skill-a"), config1 / "skills" / "skill-a")

    result = agent_helpers.bundle_links_result(config1, clone1, True)

    assert not result.passed
    assert "skill-a" in result.detail


def test_bundle_links_result_fails_for_a_copy_in_place_of_a_skill_link(tmp_path):
    config1, clone1 = make_bundle_tree(tmp_path, ["skill-a"], True)
    (config1 / "skills" / "skill-a").unlink()
    (config1 / "skills" / "skill-a").mkdir()

    result = agent_helpers.bundle_links_result(config1, clone1, True)

    assert not result.passed
    assert "skill-a" in result.detail


def test_bundle_links_result_fails_for_a_rules_link_with_another_target(tmp_path):
    config1, clone1 = make_bundle_tree(tmp_path, ["skill-a"], True)
    (tmp_path / "other1").mkdir()
    (config1 / "rules").unlink()
    os.symlink("../../other1", config1 / "rules")

    result = agent_helpers.bundle_links_result(config1, clone1, True)

    assert not result.passed
    assert "rules" in result.detail


def test_bundle_links_result_fails_for_rules_that_is_not_a_link(tmp_path):
    config1, clone1 = make_bundle_tree(tmp_path, ["skill-a"], False)
    (config1 / "rules").mkdir()

    result = agent_helpers.bundle_links_result(config1, clone1, True)

    assert not result.passed
    assert "rules" in result.detail


def test_bundle_links_result_fails_when_the_list_misses_a_skill(tmp_path):
    config1, clone1 = make_bundle_tree(tmp_path, ["skill-a", "skill-b"], True)
    (config1 / ".best-practices-skills").write_text("skill-a\n")

    result = agent_helpers.bundle_links_result(config1, clone1, True)

    assert not result.passed
    assert "skill-b" in result.detail


def test_bundle_links_result_fails_when_the_list_is_missing(tmp_path):
    config1, clone1 = make_bundle_tree(tmp_path, ["skill-a"], True)
    (config1 / ".best-practices-skills").unlink()

    result = agent_helpers.bundle_links_result(config1, clone1, True)

    assert not result.passed
    assert ".best-practices-skills" in result.detail


def test_bundle_links_result_says_there_is_no_clone_when_the_folder_the_mode_needs_is_absent(tmp_path):
    config1 = tmp_path / "state1" / "agent1"
    config1.mkdir(parents=True)
    clone1 = tmp_path / "best-practices"
    (clone1 / "rules").mkdir(parents=True)

    skills_result = agent_helpers.bundle_links_result(config1, clone1, False)
    rules_result = agent_helpers.bundle_links_result(config1, tmp_path / "missing1", True)

    assert not skills_result.passed
    assert "no clone" in skills_result.detail
    assert "sbx-bundle-clone" in skills_result.hint
    assert not rules_result.passed
    assert "no clone" in rules_result.detail


def test_bundle_links_result_without_rules_mode_passes_on_a_tree_with_no_rules_link(tmp_path):
    config1, clone1 = make_bundle_tree(tmp_path, ["skill-a", "skill-b"], False)

    result = agent_helpers.bundle_links_result(config1, clone1, False)

    assert result.passed
    assert "2 skills linked" in result.detail
    assert "rules" not in result.detail


# ------------------------------------------------------------------------------
# Home links
# ------------------------------------------------------------------------------

def test_home_links_result_passes_when_each_link_holds_its_target_text(tmp_path):
    target1 = tmp_path / "target1"
    target1.mkdir()
    link1 = tmp_path / "link1"
    link2 = tmp_path / "link2"
    os.symlink(str(target1), link1)
    os.symlink(str(target1), link2)

    result = agent_helpers.home_links_result([(link1, target1), (link2, target1)])

    assert result.passed
    assert str(link1) in result.detail
    assert str(link2) in result.detail


def test_home_links_result_fails_for_a_folder_in_place_of_a_link_and_for_another_target(tmp_path):
    target1 = tmp_path / "target1"
    target2 = tmp_path / "target2"
    target1.mkdir()
    target2.mkdir()
    folder1 = tmp_path / "folder1"
    folder1.mkdir()
    link2 = tmp_path / "link2"
    os.symlink(str(target2), link2)

    folder_result = agent_helpers.home_links_result([(folder1, target1)])
    target_result = agent_helpers.home_links_result([(link2, target1)])

    assert not folder_result.passed
    assert str(folder1) in folder_result.detail
    assert not target_result.passed
    assert str(link2) in target_result.detail
    assert target_result.hint == selfcheck_core.rebuild_hint()
