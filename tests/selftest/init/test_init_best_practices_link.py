# ------------------------------------------------------------------------------
# Tests of the best-practices links step
# ------------------------------------------------------------------------------
# Real folders and links inside tmp_path. The config folder and the clone are
# siblings under it, as in the container, so the relative link texts resolve.
# ------------------------------------------------------------------------------

import os
from pathlib import Path

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
