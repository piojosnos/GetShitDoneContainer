# ------------------------------------------------------------------------------
# Root-owned files
# ------------------------------------------------------------------------------
# The image puts this file in /usr/local/lib/sbx-selfcheck/.
# ------------------------------------------------------------------------------

import stat
from pathlib import Path

from check_result import CheckResult, problem_list_result
from hints import rebuild_hint


# ------------------------------------------------------------------------------
# Owner and mode of a list of paths
# ------------------------------------------------------------------------------

def root_owned_result(path_mode_list: list[tuple[str, int]]) -> CheckResult:
    problem_list = []

    for path, expected_mode in path_mode_list:
        try:
            path_stat = Path(path).stat()
        except FileNotFoundError:
            problem_list.append(f"{path} is missing")
            continue

        actual_mode = stat.S_IMODE(path_stat.st_mode)

        if path_stat.st_uid != 0 or path_stat.st_gid != 0 or actual_mode != expected_mode:
            problem_list.append(
                f"{path} is {path_stat.st_uid}:{path_stat.st_gid} {actual_mode:o}, expected root:root {expected_mode:o}"
            )

    return problem_list_result(
        problem_list, rebuild_hint(), f"{len(path_mode_list)} paths are root-owned with their modes"
    )
