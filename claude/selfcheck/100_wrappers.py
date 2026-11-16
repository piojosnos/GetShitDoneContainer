# ------------------------------------------------------------------------------
# Check: the Claude image folder is root-owned
# ------------------------------------------------------------------------------
# The image copies this file to /etc/sbx/selfcheck.d/claude/; the runner loads it
# after the shared checks.
# ------------------------------------------------------------------------------

from check_result import Check, CheckResult
from claude_shared import IMAGE_ROOT_LIST
from image_ownership import image_ownership_result


# ------------------------------------------------------------------------------
# Check entries
# ------------------------------------------------------------------------------

def _check_claude_wrappers() -> CheckResult:
    return image_ownership_result(IMAGE_ROOT_LIST)


CHECK_LIST = [Check("claude-wrappers", _check_claude_wrappers)]
