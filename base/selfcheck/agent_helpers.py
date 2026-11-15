# ------------------------------------------------------------------------------
# The helpers the agent check files share
# ------------------------------------------------------------------------------
# Links into the home and the bundle, the login file, the GSD sync, the versions
# line. The image puts this file in /usr/local/lib/sbx-selfcheck/.
# ------------------------------------------------------------------------------

import os
from pathlib import Path

from selfcheck_core import (
    TOOL_VERSIONS_FILE,
    VERSIONS_FILE,
    CheckResult,
    expected_base_versions_text,
    failed,
    missing_pin_result,
    one_line,
    passed,
    pin_map_or_missing,
    problem_list_result,
    rebuild_hint,
    restart_hint,
)


# ------------------------------------------------------------------------------
# Constants
# ------------------------------------------------------------------------------

RULES_LINK_TEXT = "../../best-practices/rules"
SKILL_LINK_TEXT_TEMPLATE = "../../../best-practices/skills/{name}"
BUNDLE_SKILL_LIST_NAME = ".best-practices-skills"


# ------------------------------------------------------------------------------
# Versions line
# ------------------------------------------------------------------------------

def versions_line_result(
    prefix_text: str,
    versions_line_file: Path = TOOL_VERSIONS_FILE,
    versions_file: Path = VERSIONS_FILE,
) -> CheckResult:
    try:
        expected_line = prefix_text + expected_base_versions_text(versions_file)
    except KeyError as e:
        return missing_pin_result(e.args[0])

    if not versions_line_file.is_file():
        return failed(f"{versions_line_file} is missing", rebuild_hint())

    actual_text = versions_line_file.read_text()

    if actual_text != expected_line + "\n":
        return failed(
            f"{versions_line_file} holds '{one_line(actual_text.rstrip())}'; expected '{expected_line}'",
            rebuild_hint(),
        )

    return passed(f"the line is {expected_line}")


# ------------------------------------------------------------------------------
# Login file and GSD sync
# ------------------------------------------------------------------------------

def login_file_result(login_file: Path, login_hint: str) -> CheckResult:
    if not login_file.is_file() or login_file.stat().st_size == 0:
        return failed(f"{login_file} is missing or empty", login_hint)

    return passed(f"{login_file} is there ({login_file.stat().st_size} bytes)")


def gsd_synced_result(config_dir: Path, versions_file: Path = VERSIONS_FILE) -> CheckResult:
    pin_map, missing_result = pin_map_or_missing(["GSD_CORE_VERSION"], versions_file)

    if missing_result:
        return missing_result

    pinned_version = pin_map["GSD_CORE_VERSION"]
    version_file = config_dir / "gsd-core" / "VERSION"
    hint = restart_hint() + "; the start syncs GSD"

    if not version_file.is_file():
        return failed(f"{version_file} is missing; the image has '{pinned_version}'", hint)

    synced_version = version_file.read_text().strip()

    if synced_version != pinned_version:
        return failed(f"GSD in {config_dir} is '{synced_version}'; the image has '{pinned_version}'", hint)

    return passed(f"GSD {pinned_version} in {config_dir}")


# ------------------------------------------------------------------------------
# Bundle links
# ------------------------------------------------------------------------------

def bundle_skill_name_list(bundle_dir: Path) -> list[str]:
    skills_dir = bundle_dir / "skills"
    skill_name_list = []

    if not skills_dir.is_dir():
        return skill_name_list

    for skill_dir in sorted(skills_dir.iterdir()):
        if skill_dir.is_dir() and not skill_dir.name.startswith("."):
            skill_name_list.append(skill_dir.name)

    return skill_name_list


def link_text(link: Path) -> str | None:
    try:
        return os.readlink(link)
    except OSError:
        return None


def rules_link_problem(config_dir: Path, bundle_dir: Path) -> str:
    rules_link = config_dir / "rules"
    actual_text = link_text(rules_link)

    if actual_text is None:
        return f"{rules_link} is not a link"

    if actual_text != RULES_LINK_TEXT:
        return f"{rules_link} links to '{actual_text}', expected '{RULES_LINK_TEXT}'"

    try:
        same_folder = os.path.samefile(rules_link, bundle_dir / "rules")
    except OSError:
        same_folder = False

    if not same_folder:
        return f"{rules_link} does not reach {bundle_dir / 'rules'}"

    return ""


def skill_link_problem_list(config_dir: Path, skill_name_list: list[str]) -> list[str]:
    problem_list = []

    for skill_name in skill_name_list:
        skill_link = config_dir / "skills" / skill_name
        expected_text = SKILL_LINK_TEXT_TEMPLATE.format(name=skill_name)
        actual_text = link_text(skill_link)

        if actual_text is None:
            problem_list.append(f"{skill_link} is not a link")
        elif actual_text != expected_text:
            problem_list.append(f"{skill_link} links to '{actual_text}', expected '{expected_text}'")

    return problem_list


def skill_list_problem_list(config_dir: Path, skill_name_list: list[str]) -> list[str]:
    list_file = config_dir / BUNDLE_SKILL_LIST_NAME

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


def bundle_links_result(config_dir: Path, bundle_dir: Path, links_rules: bool) -> CheckResult:
    hint = (
        "link the clone in this sandbox: run sbx-gh-login and sbx-bundle-clone when there is no clone, "
        "else /etc/sbx/start.d/10-best-practices"
    )
    needed_dir = bundle_dir / "rules" if links_rules else bundle_dir / "skills"

    if not needed_dir.is_dir():
        return failed(f"no clone at {bundle_dir}", hint)

    skill_name_list = bundle_skill_name_list(bundle_dir)
    problem_list = []

    if links_rules:
        rules_problem = rules_link_problem(config_dir, bundle_dir)

        if rules_problem:
            problem_list.append(rules_problem)

    problem_list.extend(skill_link_problem_list(config_dir, skill_name_list))
    problem_list.extend(skill_list_problem_list(config_dir, skill_name_list))

    detail = f"{len(skill_name_list)} skills linked from {bundle_dir}"

    if links_rules:
        detail += ", rules linked"

    return problem_list_result(problem_list, hint, detail)


# ------------------------------------------------------------------------------
# Home links
# ------------------------------------------------------------------------------

def home_links_result(link_target_list: list[tuple[Path, Path]]) -> CheckResult:
    problem_list = []
    pair_list = []

    for link, target in link_target_list:
        actual_text = link_text(link)

        if actual_text is None:
            problem_list.append(f"{link} is not a link")
        elif actual_text != str(target):
            problem_list.append(f"{link} links to '{actual_text}', expected '{target}'")
        else:
            pair_list.append(f"{link} -> {target}")

    return problem_list_result(problem_list, rebuild_hint(), ", ".join(pair_list))
