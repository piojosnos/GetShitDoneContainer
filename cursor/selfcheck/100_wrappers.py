# ------------------------------------------------------------------------------
# Check: the Cursor image directory is root-owned
# ------------------------------------------------------------------------------
# The image copies this file to /etc/sbx/selfcheck.d/cursor/; the runner loads it
# after the shared checks.
# ------------------------------------------------------------------------------

from check_result import Check, CheckResult
from cursor_shared import IMAGE_ROOT_LIST
from image_ownership import image_ownership_result


# ------------------------------------------------------------------------------
# Check entries
# ------------------------------------------------------------------------------

def _check_cursor_wrappers() -> CheckResult:
    return image_ownership_result(IMAGE_ROOT_LIST)


CHECK_LIST = [Check("cursor-wrappers", _check_cursor_wrappers)]
