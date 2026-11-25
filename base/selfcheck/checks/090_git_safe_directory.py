# --------------------------------------------------------------------------------
# Check: git trusts every directory
# --------------------------------------------------------------------------------
# The image puts this file in /usr/local/lib/sbx-selfcheck/checks/.
# --------------------------------------------------------------------------------

import os
from typing import Mapping

from check_result import Check, CheckResult, failed, passed
from commands import run_command
from hints import rebuild_hint


# --------------------------------------------------------------------------------
# Git safe directory
# --------------------------------------------------------------------------------

def safe_directory_result(environment_map: Mapping[str, str] = os.environ) -> CheckResult:
    completed = run_command(["git", "config", "--system", "--get-all", "safe.directory"], environment_map)

    for line in completed.stdout.splitlines():
        if line.strip() == "*":
            return passed("git trusts every directory (safe.directory is *)")

    return failed("the system git config does not set safe.directory to *", rebuild_hint())


# --------------------------------------------------------------------------------
# Check entries
# --------------------------------------------------------------------------------

def _check_git_safe_directory() -> CheckResult:
    return safe_directory_result()


CHECK_LIST = [Check("git-safe-directory", _check_git_safe_directory)]
