# ------------------------------------------------------------------------------
# Check: nothing under the Claude image folder is writable or mounted
# ------------------------------------------------------------------------------
# The image copies this file to /etc/sbx/selfcheck.d/claude/; the runner loads it
# after the shared checks.
# ------------------------------------------------------------------------------

from pathlib import Path

from check_result import Check, CheckResult
from protected_paths import protected_paths_result

_PROTECTED_PATH_LIST = [Path("/etc/claude-code")]


# ------------------------------------------------------------------------------
# Check entries
# ------------------------------------------------------------------------------

def _check_claude_image_paths_protected() -> CheckResult:
    return protected_paths_result(_PROTECTED_PATH_LIST)


CHECK_LIST = [Check("claude-image-paths-protected", _check_claude_image_paths_protected)]
