# ------------------------------------------------------------------------------
# Check: claude is the pinned version
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

def _check_tool_claude() -> CheckResult:
    pin_map, missing_result = pin_map_or_missing(["CLAUDE_CODE_VERSION"])

    if missing_result:
        return missing_result

    return tool_result("claude", ["--version"], f"{pin_map['CLAUDE_CODE_VERSION']} (Claude Code)")


CHECK_LIST = [Check("tool-claude", _check_tool_claude)]
