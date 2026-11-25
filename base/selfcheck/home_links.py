# --------------------------------------------------------------------------------
# Links from the home into an agent config directory
# --------------------------------------------------------------------------------
# The image puts this file in /usr/local/lib/sbx-selfcheck/.
# --------------------------------------------------------------------------------

from pathlib import Path

from check_result import CheckResult, problem_list_result
from hints import rebuild_hint
from paths import link_text


# --------------------------------------------------------------------------------
# Home links result
# --------------------------------------------------------------------------------

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
