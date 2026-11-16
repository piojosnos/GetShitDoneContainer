# ------------------------------------------------------------------------------
# Links from an agent's config folder into the best-practices clone
# ------------------------------------------------------------------------------
# The rules link and one link per skill, and the list of the skills the last sync
# made. The image puts this file in /usr/local/lib/sbx-selfcheck/.
# ------------------------------------------------------------------------------

from pathlib import Path

from check_result import CheckResult, failed, problem_list_result
from paths import link_text

_RULES_LINK_TEXT = "../../best-practices/rules"
_SKILL_LINK_TEXT_TEMPLATE = "../../../best-practices/skills/{name}"
_BUNDLE_SKILL_LIST_NAME = ".best-practices-skills"


# ------------------------------------------------------------------------------
# Problems of the links
# ------------------------------------------------------------------------------

def _bundle_skill_name_list(bundle_dir: Path) -> list[str]:
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

    if actual_text != _RULES_LINK_TEXT:
        return f"{rules_link} links to '{actual_text}', expected '{_RULES_LINK_TEXT}'"

    try:
        same_folder = rules_link.samefile(bundle_dir / "rules")
    except OSError:
        same_folder = False

    if not same_folder:
        return f"{rules_link} does not reach {bundle_dir / 'rules'}"

    return ""


def _skill_link_problem_list(config_dir: Path, skill_name_list: list[str]) -> list[str]:
    problem_list = []

    for skill_name in skill_name_list:
        skill_link = config_dir / "skills" / skill_name
        expected_text = _SKILL_LINK_TEXT_TEMPLATE.format(name=skill_name)
        actual_text = link_text(skill_link)

        if actual_text is None:
            problem_list.append(f"{skill_link} is not a link")
        elif actual_text != expected_text:
            problem_list.append(f"{skill_link} links to '{actual_text}', expected '{expected_text}'")

    return problem_list


def _skill_list_problem_list(config_dir: Path, skill_name_list: list[str]) -> list[str]:
    list_file = config_dir / _BUNDLE_SKILL_LIST_NAME

    if not list_file.is_file():
        return [f"{list_file} is missing"]

    listed_name_set = set()

    for line in list_file.read_text().splitlines():
        if line.strip():
            listed_name_set.add(line.strip())

    problem_list = []

    for skill_name in skill_name_list:
        if skill_name not in listed_name_set:
            problem_list.append(f"{list_file} does not list {skill_name}")

    for listed_name in sorted(listed_name_set - set(skill_name_list)):
        problem_list.append(f"{list_file} lists {listed_name}, which the clone does not have")

    return problem_list


# ------------------------------------------------------------------------------
# Bundle links result
# ------------------------------------------------------------------------------

def bundle_links_result(config_dir: Path, bundle_dir: Path, links_rules: bool) -> CheckResult:
    hint = (
        "link the clone in this sandbox: run sbx-gh-login and sbx-bundle-clone when there is no clone, "
        "else /etc/sbx/start.d/10-best-practices"
    )
    needed_dir = bundle_dir / "rules" if links_rules else bundle_dir / "skills"

    if not needed_dir.is_dir():
        return failed(f"no clone at {bundle_dir}", hint)

    skill_name_list = _bundle_skill_name_list(bundle_dir)
    problem_list = []

    if links_rules:
        rules_problem = _rules_link_problem(config_dir, bundle_dir)

        if rules_problem:
            problem_list.append(rules_problem)

    problem_list.extend(_skill_link_problem_list(config_dir, skill_name_list))
    problem_list.extend(_skill_list_problem_list(config_dir, skill_name_list))

    detail = f"{len(skill_name_list)} skills linked from {bundle_dir}"

    if links_rules:
        detail += ", rules linked"

    return problem_list_result(problem_list, hint, detail)
