# ------------------------------------------------------------------------------
# Links from an agent's config folder into the best-practices clone
# ------------------------------------------------------------------------------
# A link of init's own is one whose target lies under the clone's folder; init
# replaces it and removes it when the clone drops the skill. Anything else in the
# way (a folder, a file, a copy, a link elsewhere) is left as it is and reported.
# The only removal in this file is Path.unlink on an own link. The step does not
# check that a link resolves; the self-check does. The image puts this file in
# /usr/local/lib/sbx-init/.
# ------------------------------------------------------------------------------

from pathlib import Path

from bundle_links import (
    RULES_LINK_TEXT,
    SKILL_LINK_TEXT_TEMPLATE,
    best_practices_skill_name_list,
    clone_failure,
    is_best_practices_link,
    linked_detail,
)
from check_result import CheckResult, capped_problem_detail, failed, passed


# ------------------------------------------------------------------------------
# The linking
# ------------------------------------------------------------------------------

def link_best_practices(config_dir: Path, bundle_dir: Path, links_rules: bool) -> CheckResult:
    clone_problem = clone_failure(bundle_dir, links_rules)

    if clone_problem is not None:
        return clone_problem

    skills_dir = config_dir / "skills"
    clash_list: list[Path] = []
    problem_list: list[str] = []

    try:
        skills_dir.mkdir(parents=True, exist_ok=True)
    except OSError as e:
        problem_list.append(f"{skills_dir}: {e.strerror}")

        return _result(config_dir, bundle_dir, links_rules, 0, clash_list, problem_list)

    if links_rules:
        _place_link(config_dir / "rules", RULES_LINK_TEXT, bundle_dir / "rules", clash_list, problem_list)

    skill_name_list = best_practices_skill_name_list(bundle_dir)
    _link_skills(skills_dir, bundle_dir, skill_name_list, clash_list, problem_list)
    _remove_stale_links(skills_dir, bundle_dir, skill_name_list, problem_list)

    return _result(config_dir, bundle_dir, links_rules, len(skill_name_list), clash_list, problem_list)


# ------------------------------------------------------------------------------
# Placing links
# ------------------------------------------------------------------------------

def _place_link(
    entry: Path,
    link_text: str,
    own_root: Path,
    clash_list: list[Path],
    problem_list: list[str],
) -> None:
    try:
        if not entry.is_symlink() and not entry.exists():
            entry.symlink_to(link_text)

            return

        if is_best_practices_link(entry, own_root):
            entry.unlink()
            entry.symlink_to(link_text)

            return
    except OSError as e:
        problem_list.append(f"{entry}: {e.strerror}")

        return

    clash_list.append(entry)


def _link_skills(
    skills_dir: Path,
    bundle_dir: Path,
    skill_name_list: list[str],
    clash_list: list[Path],
    problem_list: list[str],
) -> None:
    own_root = bundle_dir / "skills"

    for skill_name in skill_name_list:
        link_text = SKILL_LINK_TEXT_TEMPLATE.format(name=skill_name)
        _place_link(skills_dir / skill_name, link_text, own_root, clash_list, problem_list)


# ------------------------------------------------------------------------------
# Removing links the clone no longer backs
# ------------------------------------------------------------------------------

def _remove_stale_links(
    skills_dir: Path,
    bundle_dir: Path,
    skill_name_list: list[str],
    problem_list: list[str],
) -> None:
    own_root = bundle_dir / "skills"

    try:
        entry_list = sorted(skills_dir.iterdir())
    except OSError as e:
        problem_list.append(f"{skills_dir}: {e.strerror}")

        return

    for entry in entry_list:
        if entry.name in skill_name_list or not is_best_practices_link(entry, own_root):
            continue

        try:
            entry.unlink()
        except OSError as e:
            problem_list.append(f"{entry}: {e.strerror}")


# ------------------------------------------------------------------------------
# The result
# ------------------------------------------------------------------------------

def _result(
    config_dir: Path,
    bundle_dir: Path,
    links_rules: bool,
    skill_count: int,
    clash_list: list[Path],
    problem_list: list[str],
) -> CheckResult:
    if problem_list:
        return failed(
            "; ".join(problem_list),
            f"make {config_dir} writable by the sandbox user, then run sbx-init again",
        )

    if clash_list:
        return _clash_result(clash_list)

    return passed(linked_detail(bundle_dir, links_rules, skill_count))


def _clash_result(clash_list: list[Path]) -> CheckResult:
    sentence_list = []

    for clash_path in clash_list:
        sentence_list.append(f"{clash_path} is not a link into the best-practices clone; it was left as it is")

    return failed(
        capped_problem_detail(sentence_list) + "; every other skill is linked",
        f"rename or move {clash_list[0]}, then run sbx-init again",
    )
