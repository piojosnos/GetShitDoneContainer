# --------------------------------------------------------------------------------
# Tests of the best-practices links step
# --------------------------------------------------------------------------------
# Real directories and links inside tmp_path. The config directory and the clone are
# siblings under it, as in the container, so the relative link texts resolve.
# --------------------------------------------------------------------------------

import os
import shutil
from pathlib import Path

import pytest

import best_practices_links
import claude_shared
import cursor_shared
from best_practices_linker import link_best_practices
from init_helpers import REPO_DIR

INTEGRATION_FIXTURE_DIR = REPO_DIR / "tests" / "integration" / "support" / "best-practices"
RULES_LINK_TEXT_TEMPLATE = "../../best-practices/generated/{agent}/rules"
SKILL_LINK_TEXT_TEMPLATE = "../../../best-practices/generated/{agent}/skills/{name}"


# --------------------------------------------------------------------------------
# Helpers
# --------------------------------------------------------------------------------

def make_trees(base_dir: Path, skill_name_list: list[str], agent_name: str) -> tuple[Path, Path]:
    config_dir = base_dir / "state1" / agent_name
    clone_dir = base_dir / "best-practices"
    generated_dir = clone_dir / "generated" / agent_name
    config_dir.mkdir(parents=True)
    (generated_dir / "rules").mkdir(parents=True)
    (generated_dir / "rules" / "rule1.md").write_text("generated rule1\n")
    (generated_dir / "skills").mkdir()

    for skill_name in skill_name_list:
        (generated_dir / "skills" / skill_name).mkdir()
        (generated_dir / "skills" / skill_name / "SKILL.md").write_text(f"clone {skill_name}\n")

    return config_dir, clone_dir


# --------------------------------------------------------------------------------
# One clone skill and the rules, linked
# --------------------------------------------------------------------------------

@pytest.mark.parametrize("agent_name", [claude_shared.AGENT_NAME, cursor_shared.AGENT_NAME])
def test_an_empty_config_dir_gets_the_rules_link_and_one_link_per_skill(tmp_path, agent_name):
    config1, clone1 = make_trees(tmp_path, ["skill1", "skill2"], agent_name)

    result = link_best_practices(config1, clone1, agent_name)

    assert result.passed
    assert result.detail == f"2 skills linked from {clone1 / 'generated' / agent_name}, rules linked"
    assert os.readlink(config1 / "rules") == RULES_LINK_TEXT_TEMPLATE.format(agent=agent_name)
    assert os.readlink(config1 / "skills" / "skill1") == SKILL_LINK_TEXT_TEMPLATE.format(agent=agent_name, name="skill1")
    assert os.readlink(config1 / "skills" / "skill2") == SKILL_LINK_TEXT_TEMPLATE.format(agent=agent_name, name="skill2")
    assert (config1 / "skills" / "skill1" / "SKILL.md").read_text() == "clone skill1\n"
    assert (config1 / "rules").samefile(clone1 / "generated" / agent_name / "rules")

    check_result = best_practices_links.best_practices_links_result(config1, clone1, agent_name)

    assert check_result.passed
    assert check_result.detail == result.detail


# --------------------------------------------------------------------------------
# Clashes with what the user keeps
# --------------------------------------------------------------------------------

def test_a_user_dir_with_a_clone_skill_name_is_left_named_and_the_rest_is_linked(tmp_path):
    config1, clone1 = make_trees(tmp_path, ["skill1", "skill2"], "agent1")
    (config1 / "skills" / "skill1").mkdir(parents=True)
    (config1 / "skills" / "skill1" / "SKILL.md").write_bytes(b"mine\n")

    result = link_best_practices(config1, clone1, "agent1")

    assert not result.passed
    assert str(config1 / "skills" / "skill1") in result.detail
    assert "every other skill is linked" in result.detail
    assert result.hint.startswith(f"rename or move {config1 / 'skills' / 'skill1'}")
    assert result.hint.endswith("run sbx-init again")
    assert (config1 / "skills" / "skill1" / "SKILL.md").read_bytes() == b"mine\n"
    assert not (config1 / "skills" / "skill1").is_symlink()
    assert os.readlink(config1 / "skills" / "skill2") == SKILL_LINK_TEXT_TEMPLATE.format(agent="agent1", name="skill2")
    assert os.readlink(config1 / "rules") == RULES_LINK_TEXT_TEMPLATE.format(agent="agent1")


def test_a_real_rules_dir_is_left_named_and_the_skills_are_linked(tmp_path):
    config1, clone1 = make_trees(tmp_path, ["skill1"], "agent1")
    (config1 / "rules").mkdir()
    (config1 / "rules" / "mine1.md").write_bytes(b"my rule\n")

    result = link_best_practices(config1, clone1, "agent1")

    assert not result.passed
    assert str(config1 / "rules") in result.detail
    assert (config1 / "rules" / "mine1.md").read_bytes() == b"my rule\n"
    assert not (config1 / "rules").is_symlink()
    assert os.readlink(config1 / "skills" / "skill1") == SKILL_LINK_TEXT_TEMPLATE.format(agent="agent1", name="skill1")


def test_a_foreign_rules_link_is_left_and_fails_the_step(tmp_path):
    config1, clone1 = make_trees(tmp_path, ["skill1"], "agent1")
    (tmp_path / "other1").mkdir()
    os.symlink("../../other1", config1 / "rules")

    result = link_best_practices(config1, clone1, "agent1")

    assert not result.passed
    assert str(config1 / "rules") in result.detail
    assert os.readlink(config1 / "rules") == "../../other1"


def test_a_link_outside_the_clone_is_left_and_named(tmp_path):
    config1, clone1 = make_trees(tmp_path, ["skill1"], "agent1")
    (tmp_path / "other1").mkdir()
    (config1 / "skills").mkdir()
    os.symlink(str(tmp_path / "other1"), config1 / "skills" / "skill1")

    result = link_best_practices(config1, clone1, "agent1")

    assert not result.passed
    assert str(config1 / "skills" / "skill1") in result.detail
    assert os.readlink(config1 / "skills" / "skill1") == str(tmp_path / "other1")


def test_a_copy_of_a_clone_skill_is_left_and_named(tmp_path):
    config1, clone1 = make_trees(tmp_path, ["skill1"], "agent1")
    (config1 / "skills" / "skill1").mkdir(parents=True)
    (config1 / "skills" / "skill1" / "SKILL.md").write_bytes(b"clone skill1\n")

    result = link_best_practices(config1, clone1, "agent1")

    assert not result.passed
    assert str(config1 / "skills" / "skill1") in result.detail
    assert not (config1 / "skills" / "skill1").is_symlink()


def test_a_gsd_skill_dir_that_shares_a_clone_skill_name_is_left_and_named(tmp_path):
    config1, clone1 = make_trees(tmp_path, ["gsd-skill1"], "agent1")
    (config1 / "skills" / "gsd-skill1").mkdir(parents=True)
    (config1 / "skills" / "gsd-skill1" / "SKILL.md").write_bytes(b"gsd\n")

    result = link_best_practices(config1, clone1, "agent1")

    assert not result.passed
    assert str(config1 / "skills" / "gsd-skill1") in result.detail
    assert (config1 / "skills" / "gsd-skill1" / "SKILL.md").read_bytes() == b"gsd\n"


def test_a_user_skill_the_clone_does_not_have_is_untouched(tmp_path):
    config1, clone1 = make_trees(tmp_path, ["skill1"], "agent1")
    (config1 / "skills" / "mine1").mkdir(parents=True)
    (config1 / "skills" / "mine1" / "SKILL.md").write_bytes(b"mine\n")

    result = link_best_practices(config1, clone1, "agent1")

    assert result.passed
    assert (config1 / "skills" / "mine1" / "SKILL.md").read_bytes() == b"mine\n"


# --------------------------------------------------------------------------------
# Init's own links
# --------------------------------------------------------------------------------

def test_an_own_link_with_an_old_absolute_text_is_replaced_by_the_relative_text(tmp_path):
    config1, clone1 = make_trees(tmp_path, ["skill1"], "agent1")
    (config1 / "skills").mkdir()
    os.symlink(str(clone1 / "generated" / "agent1" / "skills" / "skill1"), config1 / "skills" / "skill1")
    os.symlink(str(clone1 / "generated" / "agent1" / "rules"), config1 / "rules")

    result = link_best_practices(config1, clone1, "agent1")

    assert result.passed
    assert os.readlink(config1 / "skills" / "skill1") == SKILL_LINK_TEXT_TEMPLATE.format(agent="agent1", name="skill1")
    assert os.readlink(config1 / "rules") == RULES_LINK_TEXT_TEMPLATE.format(agent="agent1")


def test_a_rerun_gives_the_same_result_and_the_same_links(tmp_path):
    config1, clone1 = make_trees(tmp_path, ["skill1", "skill2"], "agent1")

    first_result = link_best_practices(config1, clone1, "agent1")
    first_text_list = [os.readlink(config1 / "rules"), os.readlink(config1 / "skills" / "skill1")]
    second_result = link_best_practices(config1, clone1, "agent1")

    assert first_result == second_result
    assert first_text_list == [os.readlink(config1 / "rules"), os.readlink(config1 / "skills" / "skill1")]
    assert sorted(entry.name for entry in (config1 / "skills").iterdir()) == ["skill1", "skill2"]


def test_a_dangling_own_link_for_a_dropped_skill_is_removed(tmp_path):
    config1, clone1 = make_trees(tmp_path, ["skill1"], "agent1")
    (config1 / "skills").mkdir()
    os.symlink(SKILL_LINK_TEXT_TEMPLATE.format(agent="agent1", name="dropped1"), config1 / "skills" / "dropped1")

    result = link_best_practices(config1, clone1, "agent1")

    assert result.passed
    assert not (config1 / "skills" / "dropped1").is_symlink()
    assert (config1 / "skills" / "skill1").is_symlink()


def test_the_old_links_into_the_masters_are_replaced_and_a_master_only_skill_link_is_removed(tmp_path):
    agent_name = claude_shared.AGENT_NAME
    config1, clone1 = make_trees(tmp_path, ["skill1"], agent_name)
    (clone1 / "rules").mkdir()
    (clone1 / "skills" / "skill1").mkdir(parents=True)
    (clone1 / "skills" / "gone1").mkdir()
    (config1 / "skills").mkdir()
    os.symlink("../../best-practices/rules", config1 / "rules")
    os.symlink("../../../best-practices/skills/skill1", config1 / "skills" / "skill1")
    os.symlink("../../../best-practices/skills/gone1", config1 / "skills" / "gone1")

    result = link_best_practices(config1, clone1, agent_name)

    assert result.passed
    assert os.readlink(config1 / "rules") == RULES_LINK_TEXT_TEMPLATE.format(agent=agent_name)
    assert os.readlink(config1 / "skills" / "skill1") == SKILL_LINK_TEXT_TEMPLATE.format(agent=agent_name, name="skill1")
    assert not (config1 / "skills" / "gone1").is_symlink()
    assert not (config1 / "skills" / "gone1").exists()
    assert best_practices_links.best_practices_links_result(config1, clone1, agent_name).passed


def test_a_list_file_from_an_older_image_is_left_byte_for_byte(tmp_path):
    config1, clone1 = make_trees(tmp_path, ["skill1"], "agent1")
    (config1 / ".best-practices-skills").write_bytes(b"skill1\nold1\n")

    result = link_best_practices(config1, clone1, "agent1")

    assert result.passed
    assert (config1 / ".best-practices-skills").read_bytes() == b"skill1\nold1\n"


# --------------------------------------------------------------------------------
# The clone's shape
# --------------------------------------------------------------------------------

def incomplete_detail(clone_dir: Path, relative_dir_text: str) -> str:
    return f"{clone_dir} exists but has no {relative_dir_text}/ directory"


def assert_incomplete_fix(hint: str, clone_dir: Path) -> None:
    assert f"git -C {clone_dir} pull" in hint
    assert "sbx-init" in hint
    assert "move it aside" in hint
    assert "sbx-best-practices-clone" in hint


@pytest.mark.parametrize("missing_name", ["rules", "skills"])
def test_a_clone_without_a_generated_dir_fails_as_incomplete_and_makes_no_link(tmp_path, missing_name):
    config1, clone1 = make_trees(tmp_path, ["skill1"], "agent1")
    shutil.rmtree(clone1 / "generated" / "agent1" / missing_name)

    result = link_best_practices(config1, clone1, "agent1")

    assert not result.passed
    assert result.detail == incomplete_detail(clone1, f"generated/agent1/{missing_name}")
    assert_incomplete_fix(result.hint, clone1)
    assert list(config1.iterdir()) == []


@pytest.mark.parametrize(("empty_name", "entry_noun"), [("rules", "rule"), ("skills", "skill")])
def test_a_clone_with_an_empty_generated_dir_fails_as_incomplete_and_keeps_the_links(tmp_path, empty_name, entry_noun):
    config1, clone1 = make_trees(tmp_path, ["skill1"], "agent1")

    assert link_best_practices(config1, clone1, "agent1").passed

    empty_dir = clone1 / "generated" / "agent1" / empty_name
    shutil.rmtree(empty_dir)
    empty_dir.mkdir()
    (empty_dir / ".hidden1").write_text("hidden\n")

    result = link_best_practices(config1, clone1, "agent1")

    assert not result.passed
    assert result.detail == f"{clone1} exists but has no {entry_noun} in generated/agent1/{empty_name}/"
    assert_incomplete_fix(result.hint, clone1)
    assert os.readlink(config1 / "skills" / "skill1") == SKILL_LINK_TEXT_TEMPLATE.format(agent="agent1", name="skill1")
    assert os.readlink(config1 / "rules") == RULES_LINK_TEXT_TEMPLATE.format(agent="agent1")


def test_a_clone_with_only_the_masters_fails_with_the_pull_fix_and_makes_no_link(tmp_path):
    config1 = tmp_path / "state1" / "agent1"
    clone1 = tmp_path / "best-practices"
    config1.mkdir(parents=True)
    (clone1 / "rules").mkdir(parents=True)
    (clone1 / "rules" / "rule1.md").write_text("master rule1\n")
    (clone1 / "skills" / "skill1").mkdir(parents=True)
    (clone1 / "skills" / "skill1" / "SKILL.md").write_text("master skill1\n")

    result = link_best_practices(config1, clone1, "agent1")

    assert not result.passed
    assert result.detail == incomplete_detail(clone1, "generated/agent1/rules")
    assert_incomplete_fix(result.hint, clone1)
    assert list(config1.iterdir()) == []


def test_no_clone_dir_fails_with_the_clone_fix(tmp_path):
    config1 = tmp_path / "state1" / "agent1"
    config1.mkdir(parents=True)
    clone1 = tmp_path / "best-practices"

    result = link_best_practices(config1, clone1, "agent1")

    assert not result.passed
    assert result.detail == f"no best-practices clone at {clone1}"
    assert "sbx-gh-login" in result.hint
    assert "sbx-best-practices-clone" in result.hint
    assert "move it aside" not in result.hint
    assert list(config1.iterdir()) == []


@pytest.mark.parametrize("kind", ["directory", "file", "link"])
def test_an_empty_dir_a_file_or_a_dangling_link_at_the_clone_path_is_incomplete_not_missing(tmp_path, kind):
    config1 = tmp_path / "state1" / "agent1"
    config1.mkdir(parents=True)
    clone1 = tmp_path / "best-practices"

    if kind == "directory":
        clone1.mkdir()
    elif kind == "file":
        clone1.write_text("not a clone\n")
    else:
        os.symlink("nowhere1", clone1)

    result = link_best_practices(config1, clone1, "agent1")

    assert not result.passed
    assert result.detail == incomplete_detail(clone1, "generated/agent1/rules")
    assert_incomplete_fix(result.hint, clone1)
    assert list(config1.iterdir()) == []


def test_init_and_the_self_check_give_the_same_text_for_an_incomplete_clone(tmp_path):
    config1, clone1 = make_trees(tmp_path, ["skill1"], "agent1")
    shutil.rmtree(clone1 / "generated" / "agent1" / "rules")

    init_result = link_best_practices(config1, clone1, "agent1")
    check_result = best_practices_links.best_practices_links_result(config1, clone1, "agent1")

    assert not init_result.passed
    assert init_result.detail == check_result.detail
    assert init_result.hint == check_result.hint


def test_a_missing_skills_dir_in_the_config_dir_is_made(tmp_path):
    config1, clone1 = make_trees(tmp_path, ["skill1"], "agent1")

    assert not (config1 / "skills").exists()

    link_best_practices(config1, clone1, "agent1")

    assert (config1 / "skills").is_dir()


def test_a_clone_dir_with_a_leading_dot_is_not_linked(tmp_path):
    config1, clone1 = make_trees(tmp_path, ["skill1", ".hidden1"], "agent1")

    result = link_best_practices(config1, clone1, "agent1")

    assert result.passed
    assert "1 skills linked" in result.detail
    assert not (config1 / "skills" / ".hidden1").is_symlink()


# --------------------------------------------------------------------------------
# The integration fixture
# --------------------------------------------------------------------------------

@pytest.mark.parametrize("agent_name", [claude_shared.AGENT_NAME, cursor_shared.AGENT_NAME])
def test_the_integration_fixture_links_and_passes_the_check_for_each_agent(tmp_path, agent_name):
    clone1 = tmp_path / "best-practices"
    config1 = tmp_path / "state1" / agent_name
    shutil.copytree(INTEGRATION_FIXTURE_DIR, clone1)
    config1.mkdir(parents=True)

    result = link_best_practices(config1, clone1, agent_name)
    check_result = best_practices_links.best_practices_links_result(config1, clone1, agent_name)

    assert result.passed
    assert result.detail == f"2 skills linked from {clone1 / 'generated' / agent_name}, rules linked"
    assert check_result.passed
    assert os.readlink(config1 / "rules") == RULES_LINK_TEXT_TEMPLATE.format(agent=agent_name)

    rule_name_list = sorted(entry.name for entry in (config1 / "rules").iterdir())

    assert rule_name_list == sorted(entry.name for entry in (clone1 / "generated" / agent_name / "rules").iterdir())

    master_rule_text = (clone1 / "rules" / "sbx-fixture-always.md").read_text()

    for rule_name in rule_name_list:
        assert (config1 / "rules" / rule_name).read_text() != master_rule_text
