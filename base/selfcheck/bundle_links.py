# ------------------------------------------------------------------------------
# Links from an agent's config folder into the best-practices clone
# ------------------------------------------------------------------------------
# The rules link and one link per skill. Init and the check share the link texts,
# the skill listing, the own-link test (a link whose target lies under the clone's
# folder), the clone failures and the passed detail. The image puts this file in
# /usr/local/lib/sbx-selfcheck/.
# ------------------------------------------------------------------------------

import os
from pathlib import Path

from check_result import CheckResult, failed, problem_list_result
from hints import init_hint
from paths import is_under, link_text, path_is_present

RULES_LINK_TEXT = "../../best-practices/rules"
SKILL_LINK_TEXT_TEMPLATE = "../../../best-practices/skills/{name}"


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


def clone_failure(bundle_dir: Path, links_rules: bool) -> CheckResult | None:
    needed_dir = bundle_dir / "rules" if links_rules else bundle_dir / "skills"

    if not path_is_present(bundle_dir):
        return _missing_clone_result(bundle_dir)

    if not needed_dir.is_dir():
        return _incomplete_clone_result(bundle_dir, needed_dir)

    return None


def linked_detail(bundle_dir: Path, links_rules: bool, skill_count: int) -> str:
    detail = f"{skill_count} skills linked from {bundle_dir}"

    if links_rules:
        detail += ", rules linked"

    return detail


def _missing_clone_result(bundle_dir: Path) -> CheckResult:
    return failed(
        f"no best-practices clone at {bundle_dir}",
        "run sbx-gh-login, then sbx-bundle-clone; it clones the repo and runs sbx-init again",
    )


def _incomplete_clone_result(bundle_dir: Path, needed_dir: Path) -> CheckResult:
    return failed(
        f"{bundle_dir} exists but has no {needed_dir.name}/ folder",
        f"check that {bundle_dir} is a clone of the best-practices repo: if it is, run git -C {bundle_dir} pull, "
        "then sbx-init; if not, move it aside, then run sbx-gh-login and sbx-bundle-clone",
    )


def best_practices_skill_name_list(bundle_dir: Path) -> list[str]:
    skills_dir = bundle_dir / "skills"
    skill_name_list = []

    if not skills_dir.is_dir():
        return skill_name_list

    for skill_dir in sorted(skills_dir.iterdir()):
        if skill_dir.is_dir() and not skill_dir.name.startswith("."):
            skill_name_list.append(skill_dir.name)

    return skill_name_list


def _rules_link_problem(config_dir: Path, bundle_dir: Path) -> str:
    rules_link = config_dir / "rules"
    actual_text = link_text(rules_link)

    if actual_text is None:
        return f"{rules_link} is not a link"

    if actual_text != RULES_LINK_TEXT:
        return f"{rules_link} links to '{actual_text}', expected '{RULES_LINK_TEXT}'"

    if not _reaches(rules_link, bundle_dir / "rules"):
        return f"{rules_link} does not reach {bundle_dir / 'rules'}"

    return ""


def _skill_link_problem_list(config_dir: Path, bundle_dir: Path, skill_name_list: list[str]) -> list[str]:
    problem_list = []

    for skill_name in skill_name_list:
        skill_link = config_dir / "skills" / skill_name
        expected_text = SKILL_LINK_TEXT_TEMPLATE.format(name=skill_name)
        actual_text = link_text(skill_link)

        if actual_text is None:
            problem_list.append(f"{skill_link} is not a link")
        elif actual_text != expected_text:
            problem_list.append(f"{skill_link} links to '{actual_text}', expected '{expected_text}'")
        elif not _reaches(skill_link, bundle_dir / "skills" / skill_name):
            problem_list.append(f"{skill_link} does not reach {bundle_dir / 'skills' / skill_name}")

    return problem_list


def _reaches(link: Path, folder: Path) -> bool:
    try:
        return link.samefile(folder)
    except OSError:
        return False


def _stale_link_problem_list(config_dir: Path, bundle_dir: Path, skill_name_list: list[str]) -> list[str]:
    skills_dir = config_dir / "skills"
    problem_list = []

    if not skills_dir.is_dir():
        return problem_list

    for entry in sorted(skills_dir.iterdir()):
        if entry.name in skill_name_list:
            continue

        if is_best_practices_link(entry, bundle_dir / "skills"):
            problem_list.append(f"{entry} links into the clone, which has no skill {entry.name}")

    return problem_list


# ------------------------------------------------------------------------------
# Bundle links result
# ------------------------------------------------------------------------------

def bundle_links_result(config_dir: Path, bundle_dir: Path, links_rules: bool) -> CheckResult:
    clone_problem = clone_failure(bundle_dir, links_rules)

    if clone_problem is not None:
        return clone_problem

    skill_name_list = best_practices_skill_name_list(bundle_dir)
    problem_list = []

    if links_rules:
        rules_problem = _rules_link_problem(config_dir, bundle_dir)

        if rules_problem:
            problem_list.append(rules_problem)

    problem_list.extend(_skill_link_problem_list(config_dir, bundle_dir, skill_name_list))
    problem_list.extend(_stale_link_problem_list(config_dir, bundle_dir, skill_name_list))

    return problem_list_result(
        problem_list,
        init_hint(),
        linked_detail(bundle_dir, links_rules, len(skill_name_list)),
    )
