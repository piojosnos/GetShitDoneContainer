# ------------------------------------------------------------------------------
# Tests of the best-practices links step
# ------------------------------------------------------------------------------
# Real folders and links inside tmp_path. The config folder and the clone are
# siblings under it, as in the container, so the relative link texts resolve.
# ------------------------------------------------------------------------------

import os
from pathlib import Path

import pytest

import bundle_links
from best_practices_link import link_best_practices
from init_helpers import REPO_DIR, load_step

RULES_LINK_TEXT = "../../best-practices/rules"
SKILL_LINK_TEXT_TEMPLATE = "../../../best-practices/skills/{name}"


# ------------------------------------------------------------------------------
# Helpers
# ------------------------------------------------------------------------------

def make_trees(base_dir: Path, skill_name_list: list[str]) -> tuple[Path, Path]:
    config_dir = base_dir / "state1" / "agent1"
    clone_dir = base_dir / "best-practices"
    config_dir.mkdir(parents=True)
    (clone_dir / "rules").mkdir(parents=True)
    (clone_dir / "skills").mkdir()

    for skill_name in skill_name_list:
        (clone_dir / "skills" / skill_name).mkdir()
        (clone_dir / "skills" / skill_name / "SKILL.md").write_text(f"clone {skill_name}\n")

    return config_dir, clone_dir


# ------------------------------------------------------------------------------
# One clone skill and the rules, linked
# ------------------------------------------------------------------------------

def test_an_empty_config_folder_gets_the_rules_link_and_one_link_per_skill(tmp_path):
    config1, clone1 = make_trees(tmp_path, ["skill1", "skill2"])

    result = link_best_practices(config1, clone1, True)

    assert result.passed
    assert "2 skills linked" in result.detail
    assert "rules linked" in result.detail
    assert os.readlink(config1 / "rules") == RULES_LINK_TEXT
    assert os.readlink(config1 / "skills" / "skill1") == SKILL_LINK_TEXT_TEMPLATE.format(name="skill1")
    assert os.readlink(config1 / "skills" / "skill2") == SKILL_LINK_TEXT_TEMPLATE.format(name="skill2")
    assert (config1 / "skills" / "skill1" / "SKILL.md").read_text() == "clone skill1\n"
    assert (config1 / "rules").samefile(clone1 / "rules")


def test_the_claude_step_file_holds_one_step_named_for_the_agent():
    step_module = load_step(REPO_DIR / "claude" / "init" / "900_best_practices_links.py")

    assert [check.name for check in step_module.STEP_LIST] == ["claude-best-practices-links"]


# ------------------------------------------------------------------------------
# Clashes with what the user keeps
# ------------------------------------------------------------------------------

def test_a_user_folder_with_a_clone_skill_name_is_left_named_and_the_rest_is_linked(tmp_path):
    config1, clone1 = make_trees(tmp_path, ["skill1", "skill2"])
    (config1 / "skills" / "skill1").mkdir(parents=True)
    (config1 / "skills" / "skill1" / "SKILL.md").write_bytes(b"mine\n")

    result = link_best_practices(config1, clone1, True)

    assert not result.passed
    assert str(config1 / "skills" / "skill1") in result.detail
    assert "every other skill is linked" in result.detail
    assert result.hint.startswith(f"rename or move {config1 / 'skills' / 'skill1'}")
    assert result.hint.endswith("run sbx-init again")
    assert (config1 / "skills" / "skill1" / "SKILL.md").read_bytes() == b"mine\n"
    assert not (config1 / "skills" / "skill1").is_symlink()
    assert os.readlink(config1 / "skills" / "skill2") == SKILL_LINK_TEXT_TEMPLATE.format(name="skill2")
    assert os.readlink(config1 / "rules") == RULES_LINK_TEXT


def test_a_real_rules_folder_is_left_named_and_the_skills_are_linked(tmp_path):
    config1, clone1 = make_trees(tmp_path, ["skill1"])
    (config1 / "rules").mkdir()
    (config1 / "rules" / "mine1.md").write_bytes(b"my rule\n")

    result = link_best_practices(config1, clone1, True)

    assert not result.passed
    assert str(config1 / "rules") in result.detail
    assert (config1 / "rules" / "mine1.md").read_bytes() == b"my rule\n"
    assert not (config1 / "rules").is_symlink()
    assert os.readlink(config1 / "skills" / "skill1") == SKILL_LINK_TEXT_TEMPLATE.format(name="skill1")


def test_a_foreign_rules_link_is_left_and_fails_the_step(tmp_path):
    config1, clone1 = make_trees(tmp_path, ["skill1"])
    (tmp_path / "other1").mkdir()
    os.symlink("../../other1", config1 / "rules")

    result = link_best_practices(config1, clone1, True)

    assert not result.passed
    assert str(config1 / "rules") in result.detail
    assert os.readlink(config1 / "rules") == "../../other1"


def test_a_link_outside_the_clone_is_left_and_named(tmp_path):
    config1, clone1 = make_trees(tmp_path, ["skill1"])
    (tmp_path / "other1").mkdir()
    (config1 / "skills").mkdir()
    os.symlink(str(tmp_path / "other1"), config1 / "skills" / "skill1")

    result = link_best_practices(config1, clone1, True)

    assert not result.passed
    assert str(config1 / "skills" / "skill1") in result.detail
    assert os.readlink(config1 / "skills" / "skill1") == str(tmp_path / "other1")


def test_a_copy_of_a_clone_skill_is_left_and_named(tmp_path):
    config1, clone1 = make_trees(tmp_path, ["skill1"])
    (config1 / "skills" / "skill1").mkdir(parents=True)
    (config1 / "skills" / "skill1" / "SKILL.md").write_bytes(b"clone skill1\n")

    result = link_best_practices(config1, clone1, True)

    assert not result.passed
    assert str(config1 / "skills" / "skill1") in result.detail
    assert not (config1 / "skills" / "skill1").is_symlink()


def test_a_gsd_skill_folder_that_shares_a_clone_skill_name_is_left_and_named(tmp_path):
    config1, clone1 = make_trees(tmp_path, ["gsd-skill1"])
    (config1 / "skills" / "gsd-skill1").mkdir(parents=True)
    (config1 / "skills" / "gsd-skill1" / "SKILL.md").write_bytes(b"gsd\n")

    result = link_best_practices(config1, clone1, True)

    assert not result.passed
    assert str(config1 / "skills" / "gsd-skill1") in result.detail
    assert (config1 / "skills" / "gsd-skill1" / "SKILL.md").read_bytes() == b"gsd\n"


def test_a_user_skill_the_clone_does_not_have_is_untouched(tmp_path):
    config1, clone1 = make_trees(tmp_path, ["skill1"])
    (config1 / "skills" / "mine1").mkdir(parents=True)
    (config1 / "skills" / "mine1" / "SKILL.md").write_bytes(b"mine\n")

    result = link_best_practices(config1, clone1, True)

    assert result.passed
    assert (config1 / "skills" / "mine1" / "SKILL.md").read_bytes() == b"mine\n"


# ------------------------------------------------------------------------------
# Init's own links
# ------------------------------------------------------------------------------

def test_an_own_link_with_an_old_absolute_text_is_replaced_by_the_relative_text(tmp_path):
    config1, clone1 = make_trees(tmp_path, ["skill1"])
    (config1 / "skills").mkdir()
    os.symlink(str(clone1 / "skills" / "skill1"), config1 / "skills" / "skill1")
    os.symlink(str(clone1 / "rules"), config1 / "rules")

    result = link_best_practices(config1, clone1, True)

    assert result.passed
    assert os.readlink(config1 / "skills" / "skill1") == SKILL_LINK_TEXT_TEMPLATE.format(name="skill1")
    assert os.readlink(config1 / "rules") == RULES_LINK_TEXT


def test_a_rerun_gives_the_same_result_and_the_same_links(tmp_path):
    config1, clone1 = make_trees(tmp_path, ["skill1", "skill2"])

    first_result = link_best_practices(config1, clone1, True)
    first_text_list = [os.readlink(config1 / "rules"), os.readlink(config1 / "skills" / "skill1")]
    second_result = link_best_practices(config1, clone1, True)

    assert first_result == second_result
    assert first_text_list == [os.readlink(config1 / "rules"), os.readlink(config1 / "skills" / "skill1")]
    assert sorted(entry.name for entry in (config1 / "skills").iterdir()) == ["skill1", "skill2"]


def test_a_dangling_own_link_for_a_dropped_skill_is_removed(tmp_path):
    config1, clone1 = make_trees(tmp_path, ["skill1"])
    (config1 / "skills").mkdir()
    os.symlink(SKILL_LINK_TEXT_TEMPLATE.format(name="dropped1"), config1 / "skills" / "dropped1")

    result = link_best_practices(config1, clone1, True)

    assert result.passed
    assert not (config1 / "skills" / "dropped1").is_symlink()
    assert (config1 / "skills" / "skill1").is_symlink()


def test_a_link_into_a_sibling_folder_of_the_clone_skills_is_kept(tmp_path):
    config1, clone1 = make_trees(tmp_path, ["skill1"])
    (clone1 / "skills-old" / "old1").mkdir(parents=True)
    (config1 / "skills").mkdir()
    os.symlink("../../../best-practices/skills-old/old1", config1 / "skills" / "old1")

    result = link_best_practices(config1, clone1, True)

    assert result.passed
    assert os.readlink(config1 / "skills" / "old1") == "../../../best-practices/skills-old/old1"


def test_a_list_file_from_an_older_image_is_left_byte_for_byte(tmp_path):
    config1, clone1 = make_trees(tmp_path, ["skill1"])
    (config1 / ".best-practices-skills").write_bytes(b"skill1\nold1\n")

    result = link_best_practices(config1, clone1, True)

    assert result.passed
    assert (config1 / ".best-practices-skills").read_bytes() == b"skill1\nold1\n"


# ------------------------------------------------------------------------------
# The clone's shape
# ------------------------------------------------------------------------------

def incomplete_detail(clone_dir: Path, folder_name: str) -> str:
    return f"{clone_dir} exists but has no {folder_name}/ folder"


def assert_incomplete_fix(hint: str, clone_dir: Path) -> None:
    assert f"git -C {clone_dir} pull" in hint
    assert "sbx-init" in hint
    assert "move it aside" in hint
    assert "sbx-best-practices-clone" in hint


def test_a_clone_folder_without_rules_fails_the_claude_step_as_incomplete_and_makes_no_link(tmp_path):
    config1, clone1 = make_trees(tmp_path, ["skill1"])
    (clone1 / "rules").rmdir()

    result = link_best_practices(config1, clone1, True)

    assert not result.passed
    assert result.detail == incomplete_detail(clone1, "rules")
    assert_incomplete_fix(result.hint, clone1)
    assert list(config1.iterdir()) == []


def test_a_clone_folder_without_skills_fails_the_cursor_step_as_incomplete_and_makes_no_link(tmp_path):
    config1, clone1 = make_trees(tmp_path, [])
    (clone1 / "skills").rmdir()

    result = link_best_practices(config1, clone1, False)

    assert not result.passed
    assert result.detail == incomplete_detail(clone1, "skills")
    assert_incomplete_fix(result.hint, clone1)
    assert list(config1.iterdir()) == []


@pytest.mark.parametrize("links_rules", [True, False])
def test_no_clone_folder_fails_both_steps_with_the_clone_fix(tmp_path, links_rules):
    config1 = tmp_path / "state1" / "agent1"
    config1.mkdir(parents=True)
    clone1 = tmp_path / "best-practices"

    result = link_best_practices(config1, clone1, links_rules)

    assert not result.passed
    assert result.detail == f"no best-practices clone at {clone1}"
    assert "sbx-gh-login" in result.hint
    assert "sbx-best-practices-clone" in result.hint
    assert "move it aside" not in result.hint
    assert list(config1.iterdir()) == []


@pytest.mark.parametrize("kind", ["folder", "file", "link"])
def test_an_empty_folder_a_file_or_a_dangling_link_at_the_clone_path_is_incomplete_not_missing(tmp_path, kind):
    config1 = tmp_path / "state1" / "agent1"
    config1.mkdir(parents=True)
    clone1 = tmp_path / "best-practices"

    if kind == "folder":
        clone1.mkdir()
    elif kind == "file":
        clone1.write_text("not a clone\n")
    else:
        os.symlink("nowhere1", clone1)

    result = link_best_practices(config1, clone1, True)

    assert not result.passed
    assert result.detail == incomplete_detail(clone1, "rules")
    assert_incomplete_fix(result.hint, clone1)
    assert list(config1.iterdir()) == []


def test_init_and_the_self_check_give_the_same_text_for_an_incomplete_clone(tmp_path):
    config1, clone1 = make_trees(tmp_path, ["skill1"])
    (clone1 / "rules").rmdir()

    init_result = link_best_practices(config1, clone1, True)
    check_result = bundle_links.bundle_links_result(config1, clone1, True)

    assert not init_result.passed
    assert init_result.detail == check_result.detail
    assert init_result.hint == check_result.hint


def test_a_clone_with_rules_and_no_skills_folder_links_rules_and_zero_skills(tmp_path):
    config1, clone1 = make_trees(tmp_path, [])
    (clone1 / "skills").rmdir()

    result = link_best_practices(config1, clone1, True)

    assert result.passed
    assert "0 skills linked" in result.detail
    assert os.readlink(config1 / "rules") == RULES_LINK_TEXT


def test_a_missing_skills_folder_in_the_config_folder_is_made(tmp_path):
    config1, clone1 = make_trees(tmp_path, ["skill1"])

    assert not (config1 / "skills").exists()

    link_best_practices(config1, clone1, True)

    assert (config1 / "skills").is_dir()


def test_a_clone_folder_with_a_leading_dot_is_not_linked(tmp_path):
    config1, clone1 = make_trees(tmp_path, ["skill1", ".hidden1"])

    result = link_best_practices(config1, clone1, True)

    assert result.passed
    assert "1 skills linked" in result.detail
    assert not (config1 / "skills" / ".hidden1").is_symlink()


# ------------------------------------------------------------------------------
# Cursor links skills only
# ------------------------------------------------------------------------------

def test_the_skills_only_step_leaves_a_real_rules_folder_and_a_foreign_rules_link_alone(tmp_path):
    config1, clone1 = make_trees(tmp_path, ["skill1"])
    (config1 / "rules").mkdir()
    (config1 / "rules" / "mine1.md").write_bytes(b"my rule\n")

    folder_result = link_best_practices(config1, clone1, False)

    assert folder_result.passed
    assert "rules" not in folder_result.detail
    assert (config1 / "rules" / "mine1.md").read_bytes() == b"my rule\n"

    (config1 / "rules" / "mine1.md").unlink()
    (config1 / "rules").rmdir()
    os.symlink("../../other1", config1 / "rules")

    link_result = link_best_practices(config1, clone1, False)

    assert link_result.passed
    assert os.readlink(config1 / "rules") == "../../other1"


def test_the_skills_only_step_makes_no_rules_link(tmp_path):
    config1, clone1 = make_trees(tmp_path, ["skill1"])

    result = link_best_practices(config1, clone1, False)

    assert result.passed
    assert not (config1 / "rules").is_symlink()
    assert not (config1 / "rules").exists()


def test_the_cursor_step_file_holds_one_step_named_for_the_agent():
    step_module = load_step(REPO_DIR / "cursor" / "init" / "900_best_practices_links.py")

    assert [check.name for check in step_module.STEP_LIST] == ["cursor-best-practices-links"]
