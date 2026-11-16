# ------------------------------------------------------------------------------
# Tests of the bundle links result
# ------------------------------------------------------------------------------
# Real files and links inside tmp_path.
# ------------------------------------------------------------------------------

import os
from pathlib import Path

import bundle_links
import hints


# ------------------------------------------------------------------------------
# Constants and helpers
# ------------------------------------------------------------------------------

RULES_LINK_TEXT = "../../best-practices/rules"


SKILL_LINK_TEXT_TEMPLATE = "../../../best-practices/skills/{name}"


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

    return config_dir, clone_dir


# ------------------------------------------------------------------------------
# Bundle links
# ------------------------------------------------------------------------------

def test_bundle_links_result_passes_on_a_linked_tree_without_any_list_file(tmp_path):
    config1, clone1 = make_bundle_tree(tmp_path, ["skill-a", "skill-b"], True)

    result = bundle_links.bundle_links_result(config1, clone1, True)

    assert result.passed
    assert "2 skills linked" in result.detail
    assert "rules linked" in result.detail


def test_bundle_links_result_fails_naming_a_missing_skill_link(tmp_path):
    config1, clone1 = make_bundle_tree(tmp_path, ["skill-a", "skill-b"], True)
    (config1 / "skills" / "skill-b").unlink()

    result = bundle_links.bundle_links_result(config1, clone1, True)

    assert not result.passed
    assert "skill-b" in result.detail
    assert "skill-a" not in result.detail
    assert result.hint == hints.init_hint()


def test_bundle_links_result_fails_for_a_skill_link_with_another_target(tmp_path):
    config1, clone1 = make_bundle_tree(tmp_path, ["skill-a"], True)
    (config1 / "skills" / "skill-a").unlink()
    os.symlink(str(clone1 / "skills" / "skill-a"), config1 / "skills" / "skill-a")

    result = bundle_links.bundle_links_result(config1, clone1, True)

    assert not result.passed
    assert "skill-a" in result.detail


def test_bundle_links_result_fails_for_a_copy_in_place_of_a_skill_link(tmp_path):
    config1, clone1 = make_bundle_tree(tmp_path, ["skill-a"], True)
    (config1 / "skills" / "skill-a").unlink()
    (config1 / "skills" / "skill-a").mkdir()

    result = bundle_links.bundle_links_result(config1, clone1, True)

    assert not result.passed
    assert "skill-a" in result.detail


def test_bundle_links_result_fails_for_a_rules_link_with_another_target(tmp_path):
    config1, clone1 = make_bundle_tree(tmp_path, ["skill-a"], True)
    (tmp_path / "other1").mkdir()
    (config1 / "rules").unlink()
    os.symlink("../../other1", config1 / "rules")

    result = bundle_links.bundle_links_result(config1, clone1, True)

    assert not result.passed
    assert "rules" in result.detail


def test_bundle_links_result_fails_for_rules_that_is_not_a_link(tmp_path):
    config1, clone1 = make_bundle_tree(tmp_path, ["skill-a"], False)
    (config1 / "rules").mkdir()

    result = bundle_links.bundle_links_result(config1, clone1, True)

    assert not result.passed
    assert "rules" in result.detail


def test_bundle_links_result_says_there_is_no_clone_when_the_folder_the_mode_needs_is_absent(tmp_path):
    config1 = tmp_path / "state1" / "agent1"
    config1.mkdir(parents=True)
    clone1 = tmp_path / "best-practices"
    (clone1 / "rules").mkdir(parents=True)

    skills_result = bundle_links.bundle_links_result(config1, clone1, False)
    rules_result = bundle_links.bundle_links_result(config1, tmp_path / "missing1", True)

    assert not skills_result.passed
    assert "no clone" in skills_result.detail
    assert "sbx-gh-login" in skills_result.hint
    assert "sbx-bundle-clone" in skills_result.hint
    assert not rules_result.passed
    assert "no clone" in rules_result.detail
    assert "sbx-bundle-clone" in rules_result.hint


def test_bundle_links_result_without_rules_mode_passes_on_a_tree_with_no_rules_link(tmp_path):
    config1, clone1 = make_bundle_tree(tmp_path, ["skill-a", "skill-b"], False)

    result = bundle_links.bundle_links_result(config1, clone1, False)

    assert result.passed
    assert "2 skills linked" in result.detail
    assert "rules" not in result.detail


def test_bundle_links_result_fails_for_a_skill_link_with_the_right_text_that_misses_the_clone_folder(tmp_path):
    config1 = tmp_path / "state1" / "agent1"
    clone1 = tmp_path / "elsewhere1" / "best-practices"
    (config1 / "skills").mkdir(parents=True)
    (clone1 / "skills" / "skill-a").mkdir(parents=True)
    os.symlink(SKILL_LINK_TEXT_TEMPLATE.format(name="skill-a"), config1 / "skills" / "skill-a")

    result = bundle_links.bundle_links_result(config1, clone1, False)

    assert not result.passed
    assert f"{config1 / 'skills' / 'skill-a'} does not reach {clone1 / 'skills' / 'skill-a'}" in result.detail
    assert result.hint == hints.init_hint()


def test_bundle_links_result_fails_for_an_own_link_whose_skill_the_clone_dropped(tmp_path):
    config1, clone1 = make_bundle_tree(tmp_path, ["skill-a"], True)
    os.symlink(SKILL_LINK_TEXT_TEMPLATE.format(name="dropped-b"), config1 / "skills" / "dropped-b")

    result = bundle_links.bundle_links_result(config1, clone1, True)

    assert not result.passed
    assert "dropped-b" in result.detail
    assert "skill-a" not in result.detail
    assert result.hint == hints.init_hint()


def test_bundle_links_result_ignores_a_user_skill_and_a_link_elsewhere_that_the_clone_does_not_have(tmp_path):
    config1, clone1 = make_bundle_tree(tmp_path, ["skill-a"], True)
    (config1 / "skills" / "mine-b").mkdir()
    (tmp_path / "other1").mkdir()
    os.symlink("../../../other1", config1 / "skills" / "other-c")

    result = bundle_links.bundle_links_result(config1, clone1, True)

    assert result.passed
