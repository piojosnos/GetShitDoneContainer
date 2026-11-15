# ------------------------------------------------------------------------------
# Check: the versions line starts with the Claude fields
# ------------------------------------------------------------------------------
# The image copies this file to /etc/sbx/selfcheck.d/claude/; the runner loads it
# after the shared checks.
# ------------------------------------------------------------------------------

from check_result import Check, CheckResult
from pins import pin_map_or_missing
from versions_text import versions_line_result


# ------------------------------------------------------------------------------
# Check entries
# ------------------------------------------------------------------------------

def _check_claude_versions_line() -> CheckResult:
    pin_map, missing_result = pin_map_or_missing(["CLAUDE_CODE_VERSION", "CCUSAGE_VERSION"])

    if missing_result:
        return missing_result

    return versions_line_result(
        f"claude {pin_map['CLAUDE_CODE_VERSION']} | ccusage {pin_map['CCUSAGE_VERSION']} | "
    )


CHECK_LIST = [Check("claude-versions-line", _check_claude_versions_line)]
