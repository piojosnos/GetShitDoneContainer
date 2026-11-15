# ------------------------------------------------------------------------------
# Check: git has a name and an email
# ------------------------------------------------------------------------------
# The image puts this file in /usr/local/lib/sbx-selfcheck/checks/.
# ------------------------------------------------------------------------------

import os
from typing import Mapping

from check_result import Check, CheckResult, failed, passed
from commands import run_command


# ------------------------------------------------------------------------------
# Git identity
# ------------------------------------------------------------------------------

def git_identity_result(environment_map: Mapping[str, str] = os.environ) -> CheckResult:
    empty_list = []

    for key in ["user.name", "user.email"]:
        completed = run_command(["git", "config", "--global", key], environment_map)

        if not completed.stdout.strip():
            empty_list.append(key)

    if empty_list:
        return failed(
            f"{' and '.join(empty_list)} not set in the global git config",
            "run sbx-gh-login in this sandbox; it asks for the name and email",
        )

    return passed("user.name and user.email are set")


# ------------------------------------------------------------------------------
# Check entries
# ------------------------------------------------------------------------------

def _check_git_identity() -> CheckResult:
    return git_identity_result()


CHECK_LIST = [Check("git-identity", _check_git_identity)]
