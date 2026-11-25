# ------------------------------------------------------------------------------
# Links from an agent config directory into the best-practices clone
# ------------------------------------------------------------------------------
# The links go into generated/AGENT/ of the clone: the rules directory whole and one
# link per skill. Init and the check share the link texts, the skill listing, the
# own-link test (a link whose target lies anywhere under the clone's directory), the
# clone failures and the passed detail. The image puts this file in
# /usr/local/lib/sbx-selfcheck/.
# ------------------------------------------------------------------------------

import os
from pathlib import Path

from check_result import CheckResult, failed, problem_list_result
from hints import init_hint
from paths import is_under, link_text, path_is_present

RULES_LINK_TEXT_TEMPLATE = "../../best-practices/generated/{agent}/rules"
SKILL_LINK_TEXT_TEMPLATE = "../../../best-practices/generated/{agent}/skills/{name}"


# ------------------------------------------------------------------------------
# What init and the check share
# ------------------------------------------------------------------------------
# The own-link test is purely lexical: no path resolution and no existence test,
# so a dangling link into the clone still counts as init's own.
# ------------------------------------------------------------------------------

def is_best_practices_link(link: Path, target_root: Path) -> bool:
    if not link.is_symlink():
        return False

    actual_text = link_text(link)

    if actual_text is None:
        return False

    target = os.path.normpath(os.path.join(link.parent, actual_text))

    return is_under(target, str(target_root))


def generated_dir(best_practices_dir: Path, agent_name: str) -> Path:
    return best_practices_dir / "generated" / agent_name


def clone_failure(best_practices_dir: Path, agent_name: str) -> CheckResult | None:
    if not path_is_present(best_practices_dir):
        return _missing_clone_result(best_practices_dir)

    for needed_name in ["rules", "skills"]:
        needed_dir = generated_dir(best_practices_dir, agent_name) / needed_name

        if not needed_dir.is_dir():
            return _incomplete_clone_result(best_practices_dir, needed_dir)

    return None


def linked_detail(best_practices_dir: Path, agent_name: str, skill_count: int) -> str:
    return f"{skill_count} skills linked from {generated_dir(best_practices_dir, agent_name)}, rules linked"


def _missing_clone_result(best_practices_dir: Path) -> CheckResult:
    return failed(
        f"no best-practices clone at {best_practices_dir}",
        "run sbx-gh-login, then sbx-best-practices-clone; it clones the repo and runs sbx-init again",
    )


def _incomplete_clone_result(best_practices_dir: Path, needed_dir: Path) -> CheckResult:
    return failed(
        f"{best_practices_dir} exists but has no {needed_dir.relative_to(best_practices_dir)}/ directory",
        f"check that {best_practices_dir} is a clone of the best-practices repo: "
        f"if it is, run git -C {best_practices_dir} pull, "
        "then sbx-init; if not, move it aside, then run sbx-gh-login and sbx-best-practices-clone",
    )


def best_practices_skill_name_list(best_practices_dir: Path, agent_name: str) -> list[str]:
    skills_dir = generated_dir(best_practices_dir, agent_name) / "skills"
    skill_name_list = []

    if not skills_dir.is_dir():
        return skill_name_list

    for skill_dir in sorted(skills_dir.iterdir()):
        if skill_dir.is_dir() and not skill_dir.name.startswith("."):
            skill_name_list.append(skill_dir.name)

    return skill_name_list


def _rules_link_problem(config_dir: Path, best_practices_dir: Path, agent_name: str) -> str:
    rules_link = config_dir / "rules"
    expected_text = RULES_LINK_TEXT_TEMPLATE.format(agent=agent_name)
    expected_dir = generated_dir(best_practices_dir, agent_name) / "rules"
    actual_text = link_text(rules_link)

    if actual_text is None:
        return f"{rules_link} is not a link"

    if actual_text != expected_text:
        return f"{rules_link} links to '{actual_text}', expected '{expected_text}'"

    if not _reaches(rules_link, expected_dir):
        return f"{rules_link} does not reach {expected_dir}"

    return ""


def _skill_link_problem_list(
    config_dir: Path,
    best_practices_dir: Path,
    agent_name: str,
    skill_name_list: list[str],
) -> list[str]:
    problem_list = []

    for skill_name in skill_name_list:
        skill_link = config_dir / "skills" / skill_name
        expected_text = SKILL_LINK_TEXT_TEMPLATE.format(agent=agent_name, name=skill_name)
        expected_dir = generated_dir(best_practices_dir, agent_name) / "skills" / skill_name
        actual_text = link_text(skill_link)

        if actual_text is None:
            problem_list.append(f"{skill_link} is not a link")
        elif actual_text != expected_text:
            problem_list.append(f"{skill_link} links to '{actual_text}', expected '{expected_text}'")
        elif not _reaches(skill_link, expected_dir):
            problem_list.append(f"{skill_link} does not reach {expected_dir}")

    return problem_list


def _reaches(link: Path, dir_path: Path) -> bool:
    try:
        return link.samefile(dir_path)
    except OSError:
        return False


def _stale_link_problem_list(config_dir: Path, best_practices_dir: Path, skill_name_list: list[str]) -> list[str]:
    skills_dir = config_dir / "skills"
    problem_list = []

    if not skills_dir.is_dir():
        return problem_list

    for entry in sorted(skills_dir.iterdir()):
        if entry.name in skill_name_list:
            continue

        if is_best_practices_link(entry, best_practices_dir):
            problem_list.append(f"{entry} links into the clone, which has no skill {entry.name}")

    return problem_list


# ------------------------------------------------------------------------------
# Best-practices links result
# ------------------------------------------------------------------------------

def best_practices_links_result(config_dir: Path, best_practices_dir: Path, agent_name: str) -> CheckResult:
    clone_problem = clone_failure(best_practices_dir, agent_name)

    if clone_problem is not None:
        return clone_problem

    skill_name_list = best_practices_skill_name_list(best_practices_dir, agent_name)
    problem_list = []
    rules_problem = _rules_link_problem(config_dir, best_practices_dir, agent_name)

    if rules_problem:
        problem_list.append(rules_problem)

    problem_list.extend(_skill_link_problem_list(config_dir, best_practices_dir, agent_name, skill_name_list))
    problem_list.extend(_stale_link_problem_list(config_dir, best_practices_dir, skill_name_list))

    return problem_list_result(
        problem_list,
        init_hint(),
        linked_detail(best_practices_dir, agent_name, len(skill_name_list)),
    )
