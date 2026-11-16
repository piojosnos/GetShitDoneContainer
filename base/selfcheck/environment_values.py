# ------------------------------------------------------------------------------
# Environment values
# ------------------------------------------------------------------------------
# The image puts this file in /usr/local/lib/sbx-selfcheck/.
# ------------------------------------------------------------------------------

import os
from typing import Mapping

from check_result import CheckResult, problem_list_result
from hints import rebuild_hint


# ------------------------------------------------------------------------------
# Expected values of environment variables
# ------------------------------------------------------------------------------

def environment_values_result(
    expected_value_by_name_map: Mapping[str, str],
    environment_map: Mapping[str, str] = os.environ,
) -> CheckResult:
    problem_list = []
    pair_list = []

    for name, expected_value in expected_value_by_name_map.items():
        if name not in environment_map:
            problem_list.append(f"{name} is not set")
            continue

        actual_value = environment_map[name]

        if actual_value != expected_value:
            problem_list.append(f"{name} is '{actual_value}', expected '{expected_value}'")
            continue

        pair_list.append(f"{name}={actual_value}")

    return problem_list_result(
        problem_list,
        "open a fresh shell with sbx-shell; if it stays, " + rebuild_hint(environment_map),
        ", ".join(pair_list),
    )
