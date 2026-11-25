# --------------------------------------------------------------------------------
# Links from an agent config directory into the best-practices clone
# --------------------------------------------------------------------------------
# A link of init's own is one whose target lies anywhere under the clone's directory;
# init replaces it and removes it when the clone drops the skill. Anything else in the
# way (a directory, a file, a copy, a link elsewhere) is left as it is and reported.
# The only removal in this file is Path.unlink on an own link. The step does not
# check that a link resolves; sbx-selfcheck does. The image puts this file in
# /usr/local/lib/sbx-init/.
# --------------------------------------------------------------------------------

from pathlib import Path

from best_practices_links import (
    RULES_LINK_TEXT_TEMPLATE,
    SKILL_LINK_TEXT_TEMPLATE,
    best_practices_skill_name_list,
    clone_failure,
    is_best_practices_link,
    linked_detail,
)
from check_result import CheckResult, capped_problem_detail, failed, passed


# --------------------------------------------------------------------------------
# The linking
# --------------------------------------------------------------------------------

def link_best_practices(config_dir: Path, best_practices_dir: Path, agent_name: str) -> CheckResult:
    clone_problem = clone_failure(best_practices_dir, agent_name)

    if clone_problem is not None:
        return clone_problem

    skills_dir = config_dir / "skills"
    clash_list: list[Path] = []
    problem_list: list[str] = []

    try:
        skills_dir.mkdir(parents=True, exist_ok=True)
    except OSError as e:
        problem_list.append(f"{skills_dir}: {e.strerror}")

        return _result(config_dir, best_practices_dir, agent_name, 0, clash_list, problem_list)

    rules_link_text = RULES_LINK_TEXT_TEMPLATE.format(agent=agent_name)
    _place_link(config_dir / "rules", rules_link_text, best_practices_dir, clash_list, problem_list)

    skill_name_list = best_practices_skill_name_list(best_practices_dir, agent_name)
    _link_skills(skills_dir, best_practices_dir, agent_name, skill_name_list, clash_list, problem_list)
    _remove_stale_links(skills_dir, best_practices_dir, skill_name_list, problem_list)

    return _result(config_dir, best_practices_dir, agent_name, len(skill_name_list), clash_list, problem_list)


# --------------------------------------------------------------------------------
# Placing links
# --------------------------------------------------------------------------------

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
    best_practices_dir: Path,
    agent_name: str,
    skill_name_list: list[str],
    clash_list: list[Path],
    problem_list: list[str],
) -> None:
    for skill_name in skill_name_list:
        link_text = SKILL_LINK_TEXT_TEMPLATE.format(agent=agent_name, name=skill_name)
        _place_link(skills_dir / skill_name, link_text, best_practices_dir, clash_list, problem_list)


# --------------------------------------------------------------------------------
# Removing links the clone no longer backs
# --------------------------------------------------------------------------------

def _remove_stale_links(
    skills_dir: Path,
    best_practices_dir: Path,
    skill_name_list: list[str],
    problem_list: list[str],
) -> None:
    try:
        entry_list = sorted(skills_dir.iterdir())
    except OSError as e:
        problem_list.append(f"{skills_dir}: {e.strerror}")

        return

    for entry in entry_list:
        if entry.name in skill_name_list or not is_best_practices_link(entry, best_practices_dir):
            continue

        try:
            entry.unlink()
        except OSError as e:
            problem_list.append(f"{entry}: {e.strerror}")


# --------------------------------------------------------------------------------
# The result
# --------------------------------------------------------------------------------

def _result(
    config_dir: Path,
    best_practices_dir: Path,
    agent_name: str,
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

    return passed(linked_detail(best_practices_dir, agent_name, skill_count))


def _clash_result(clash_list: list[Path]) -> CheckResult:
    sentence_list = []

    for clash_path in clash_list:
        sentence_list.append(f"{clash_path} is not a link into the best-practices clone; it was left as it is")

    return failed(
        capped_problem_detail(sentence_list) + "; every other skill is linked",
        f"rename or move {clash_list[0]}, then run sbx-init again",
    )
