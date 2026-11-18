# ------------------------------------------------------------------------------
# Check: the home directories belong to the sandbox user
# ------------------------------------------------------------------------------
# The image puts this file in /usr/local/lib/sbx-selfcheck/checks/.
# ------------------------------------------------------------------------------

from pathlib import Path

from check_result import Check, CheckResult, problem_list_result
from hints import rebuild_hint
from paths import HOME_DIR
from users import SANDBOX_USER, user_name_of


# ------------------------------------------------------------------------------
# Home owners
# ------------------------------------------------------------------------------

def owned_by_result(path_list: list[Path], owner_name: str) -> CheckResult:
    problem_list = []

    for path in path_list:
        if not path.exists():
            problem_list.append(f"{path} is missing")
            continue

        actual_owner = user_name_of(path.stat().st_uid)

        if actual_owner != owner_name:
            problem_list.append(f"{path} is owned by {actual_owner}, expected {owner_name}")

    return problem_list_result(problem_list, rebuild_hint(), f"{len(path_list)} paths are owned by {owner_name}")


# ------------------------------------------------------------------------------
# Check entries
# ------------------------------------------------------------------------------

def _check_home_owners() -> CheckResult:
    return owned_by_result([HOME_DIR / ".local", HOME_DIR / ".local" / "state"], SANDBOX_USER)


CHECK_LIST = [Check("home-owners", _check_home_owners)]
