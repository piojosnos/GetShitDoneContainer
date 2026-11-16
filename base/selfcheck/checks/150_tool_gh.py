# ------------------------------------------------------------------------------
# Check: gh is the pinned version
# ------------------------------------------------------------------------------
# The image puts this file in /usr/local/lib/sbx-selfcheck/checks/.
# ------------------------------------------------------------------------------

from pathlib import Path

from check_result import Check, CheckResult
from paths import VERSIONS_FILE
from pins import pin_map_or_missing
from tools import tool_result


# ------------------------------------------------------------------------------
# Tool gh
# ------------------------------------------------------------------------------

def tool_gh_result(versions_file: Path = VERSIONS_FILE) -> CheckResult:
    pin_map, missing_result = pin_map_or_missing(["GH_VERSION"], versions_file)

    if missing_result:
        return missing_result

    return tool_result("gh", ["--version"], f"gh version {pin_map['GH_VERSION']}")


# ------------------------------------------------------------------------------
# Check entries
# ------------------------------------------------------------------------------

def _check_tool_gh() -> CheckResult:
    return tool_gh_result()


CHECK_LIST = [Check("tool-gh", _check_tool_gh)]
