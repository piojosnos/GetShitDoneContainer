# ------------------------------------------------------------------------------
# Check: the versions line starts with the Cursor field
# ------------------------------------------------------------------------------
# The image copies this file to /etc/sbx/selfcheck.d/cursor/; the runner loads it
# after the shared checks.
# ------------------------------------------------------------------------------

from check_result import Check, CheckResult
from pins import pin_map_or_missing
from versions_text import versions_line_result


# ------------------------------------------------------------------------------
# Check entries
# ------------------------------------------------------------------------------

def _check_cursor_versions_line() -> CheckResult:
    pin_map, missing_result = pin_map_or_missing(["CURSOR_AGENT_VERSION"])

    if missing_result:
        return missing_result

    return versions_line_result(f"cursor-agent {pin_map['CURSOR_AGENT_VERSION']} | ")


CHECK_LIST = [Check("cursor-versions-line", _check_cursor_versions_line)]
