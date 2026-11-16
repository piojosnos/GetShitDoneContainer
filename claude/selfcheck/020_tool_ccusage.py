# ------------------------------------------------------------------------------
# Check: ccusage is the pinned version
# ------------------------------------------------------------------------------
# The image copies this file to /etc/sbx/selfcheck.d/claude/; the runner loads it
# after the shared checks.
# ------------------------------------------------------------------------------

from check_result import Check, CheckResult
from pins import pin_map_or_missing
from tools import tool_result


# ------------------------------------------------------------------------------
# Check entries
# ------------------------------------------------------------------------------

def _check_tool_ccusage() -> CheckResult:
    pin_map, missing_result = pin_map_or_missing(["CCUSAGE_VERSION"])

    if missing_result:
        return missing_result

    return tool_result("ccusage", ["--version"], f"ccusage {pin_map['CCUSAGE_VERSION']}")


CHECK_LIST = [Check("tool-ccusage", _check_tool_ccusage)]
