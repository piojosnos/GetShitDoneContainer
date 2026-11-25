# ------------------------------------------------------------------------------
# Tests of the best-practices links result
# ------------------------------------------------------------------------------
# Real files and links inside tmp_path.
# ------------------------------------------------------------------------------

import os
from pathlib import Path

import best_practices_links
import hints


# ------------------------------------------------------------------------------
# Constants and helpers
# ------------------------------------------------------------------------------

RULES_LINK_TEXT_TEMPLATE = "../../best-practices/generated/{agent}/rules"


SKILL_LINK_TEXT_TEMPLATE = "../../../best-practices/generated/{agent}/skills/{name}"


def make_best_practices_tree(base_dir: Path, skill_name_list: list[str], agent_name: str) -> tuple[Path, Path]:
    config_dir = base_dir / "state1" / agent_name
    clone_dir = base_dir / "best-practices"
    generated_dir = clone_dir / "generated" / agent_name
    (config_dir / "skills").mkdir(parents=True)
    (generated_dir / "rules").mkdir(parents=True)
    (generated_dir / "skills").mkdir()
    os.symlink(RULES_LINK_TEXT_TEMPLATE.format(agent=agent_name), config_dir / "rules")

    for skill_name in skill_name_list:
        (generated_dir / "skills" / skill_name).mkdir()
        os.symlink(
            SKILL_LINK_TEXT_TEMPLATE.format(agent=agent_name, name=skill_name),
            config_dir / "skills" / skill_name,
        )

    return config_dir, clone_dir


# ------------------------------------------------------------------------------
# Best-practices links
# ------------------------------------------------------------------------------

def test_best_practices_links_result_passes_on_a_linked_tree_without_any_list_file(tmp_path):
    config1, clone1 = make_best_practices_tree(tmp_path, ["skill-a", "skill-b"], "agent1")

    result = best_practices_links.best_practices_links_result(config1, clone1, "agent1")

    assert result.passed
    assert "2 skills linked" in result.detail
    assert "rules linked" in result.detail


def test_best_practices_links_result_fails_naming_a_missing_skill_link(tmp_path):
    config1, clone1 = make_best_practices_tree(tmp_path, ["skill-a", "skill-b"], "agent1")
    (config1 / "skills" / "skill-b").unlink()

    result = best_practices_links.best_practices_links_result(config1, clone1, "agent1")

    assert not result.passed
    assert "skill-b" in result.detail
    assert "skill-a" not in result.detail
    assert result.hint == hints.init_hint()


def test_best_practices_links_result_fails_for_a_skill_link_with_another_target(tmp_path):
    config1, clone1 = make_best_practices_tree(tmp_path, ["skill-a"], "agent1")
    (config1 / "skills" / "skill-a").unlink()
    os.symlink(str(clone1 / "generated" / "agent1" / "skills" / "skill-a"), config1 / "skills" / "skill-a")

    result = best_practices_links.best_practices_links_result(config1, clone1, "agent1")

    assert not result.passed
    assert "skill-a" in result.detail


def test_best_practices_links_result_fails_for_a_copy_in_place_of_a_skill_link(tmp_path):
    config1, clone1 = make_best_practices_tree(tmp_path, ["skill-a"], "agent1")
    (config1 / "skills" / "skill-a").unlink()
    (config1 / "skills" / "skill-a").mkdir()

    result = best_practices_links.best_practices_links_result(config1, clone1, "agent1")

    assert not result.passed
    assert "skill-a" in result.detail


def test_best_practices_links_result_fails_for_a_rules_link_with_another_target(tmp_path):
    config1, clone1 = make_best_practices_tree(tmp_path, ["skill-a"], "agent1")
    (tmp_path / "other1").mkdir()
    (config1 / "rules").unlink()
    os.symlink("../../other1", config1 / "rules")

    result = best_practices_links.best_practices_links_result(config1, clone1, "agent1")

    assert not result.passed
    assert "rules" in result.detail


def test_best_practices_links_result_fails_for_rules_that_is_not_a_link(tmp_path):
    config1, clone1 = make_best_practices_tree(tmp_path, ["skill-a"], "agent1")
    (config1 / "rules").unlink()
    (config1 / "rules").mkdir()

    result = best_practices_links.best_practices_links_result(config1, clone1, "agent1")

    assert not result.passed
    assert "rules" in result.detail


def test_the_links_result_says_there_is_no_clone_when_the_clone_dir_is_absent(tmp_path):
    config1 = tmp_path / "state1" / "agent1"
    config1.mkdir(parents=True)
    clone1 = tmp_path / "missing1"

    result = best_practices_links.best_practices_links_result(config1, clone1, "agent1")

    assert not result.passed
    assert result.detail == f"no best-practices clone at {clone1}"
    assert "sbx-gh-login" in result.hint
    assert "sbx-best-practices-clone" in result.hint
    assert "move it aside" not in result.hint


def test_the_links_result_names_the_dir_a_clone_dir_lacks(tmp_path):
    config1 = tmp_path / "state1" / "agent1"
    config1.mkdir(parents=True)
    clone1 = tmp_path / "best-practices"
    (clone1 / "generated" / "agent1" / "rules").mkdir(parents=True)

    skills_result = best_practices_links.best_practices_links_result(config1, clone1, "agent1")

    (clone1 / "generated" / "agent1" / "rules").rmdir()
    (clone1 / "generated" / "agent1" / "skills").mkdir()

    rules_result = best_practices_links.best_practices_links_result(config1, clone1, "agent1")

    assert not skills_result.passed
    assert skills_result.detail == f"{clone1} exists but has no generated/agent1/skills/ directory"
    assert not rules_result.passed
    assert rules_result.detail == f"{clone1} exists but has no generated/agent1/rules/ directory"

    for result in [skills_result, rules_result]:
        assert f"git -C {clone1} pull" in result.hint
        assert "sbx-init" in result.hint
        assert "move it aside" in result.hint
        assert "sbx-best-practices-clone" in result.hint


def test_best_practices_links_result_fails_for_a_skill_link_with_the_right_text_that_misses_the_clone_dir(tmp_path):
    config1 = tmp_path / "state1" / "agent1"
    clone1 = tmp_path / "elsewhere1" / "best-practices"
    (config1 / "skills").mkdir(parents=True)
    (clone1 / "generated" / "agent1" / "rules").mkdir(parents=True)
    (clone1 / "generated" / "agent1" / "skills" / "skill-a").mkdir(parents=True)
    os.symlink(SKILL_LINK_TEXT_TEMPLATE.format(agent="agent1", name="skill-a"), config1 / "skills" / "skill-a")
    os.symlink(RULES_LINK_TEXT_TEMPLATE.format(agent="agent1"), config1 / "rules")

    result = best_practices_links.best_practices_links_result(config1, clone1, "agent1")
    expected_dir = clone1 / "generated" / "agent1" / "skills" / "skill-a"

    assert not result.passed
    assert f"{config1 / 'skills' / 'skill-a'} does not reach {expected_dir}" in result.detail
    assert result.hint == hints.init_hint()


def test_best_practices_links_result_fails_for_an_own_link_whose_skill_the_clone_dropped(tmp_path):
    config1, clone1 = make_best_practices_tree(tmp_path, ["skill-a"], "agent1")
    os.symlink(SKILL_LINK_TEXT_TEMPLATE.format(agent="agent1", name="dropped-b"), config1 / "skills" / "dropped-b")

    result = best_practices_links.best_practices_links_result(config1, clone1, "agent1")

    assert not result.passed
    assert "dropped-b" in result.detail
    assert "skill-a" not in result.detail
    assert result.hint == hints.init_hint()


def test_best_practices_links_result_ignores_a_user_skill_and_a_link_elsewhere_that_the_clone_does_not_have(tmp_path):
    config1, clone1 = make_best_practices_tree(tmp_path, ["skill-a"], "agent1")
    (config1 / "skills" / "mine-b").mkdir()
    (tmp_path / "other1").mkdir()
    os.symlink("../../../other1", config1 / "skills" / "other-c")

    result = best_practices_links.best_practices_links_result(config1, clone1, "agent1")

    assert result.passed


# ------------------------------------------------------------------------------
# Clone failures and the passed detail
# ------------------------------------------------------------------------------

def test_clone_failure_is_none_for_a_clone_with_what_the_agent_needs(tmp_path):
    clone1 = tmp_path / "best-practices"
    (clone1 / "generated" / "agent1" / "skills").mkdir(parents=True)

    assert best_practices_links.clone_failure(clone1, "agent1").detail == (
        f"{clone1} exists but has no generated/agent1/rules/ directory"
    )

    (clone1 / "generated" / "agent1" / "rules").mkdir()

    assert best_practices_links.clone_failure(clone1, "agent1") is None


def test_linked_detail_counts_skills_and_names_the_generated_dir(tmp_path):
    assert best_practices_links.linked_detail(tmp_path, "agent1", 3) == (
        f"3 skills linked from {tmp_path / 'generated' / 'agent1'}, rules linked"
    )
