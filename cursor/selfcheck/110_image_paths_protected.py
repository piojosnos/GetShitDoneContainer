# ------------------------------------------------------------------------------
# Check: nothing under the Cursor image folder is writable or mounted
# ------------------------------------------------------------------------------
# The image copies this file to /etc/sbx/selfcheck.d/cursor/; the runner loads it
# after the shared checks.
# ------------------------------------------------------------------------------

from pathlib import Path

from check_result import Check, CheckResult
from protected_paths import protected_paths_result

_PROTECTED_PATH_LIST = [Path("/usr/local/lib/cursor-agent")]


# ------------------------------------------------------------------------------
# Check entries
# ------------------------------------------------------------------------------

def _check_cursor_image_paths_protected() -> CheckResult:
    return protected_paths_result(_PROTECTED_PATH_LIST)


CHECK_LIST = [Check("cursor-image-paths-protected", _check_cursor_image_paths_protected)]
