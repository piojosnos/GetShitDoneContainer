# ------------------------------------------------------------------------------
# Step: sync the image's GSD into the Cursor config folder
# ------------------------------------------------------------------------------
# The image copies this file to /etc/sbx/init.d/cursor/; the runner sorts it in
# by file name.
# ------------------------------------------------------------------------------

from check_result import Check, CheckResult
from cursor_shared import CONFIG_DIR
from gsd_sync import gsd_sync_result


# ------------------------------------------------------------------------------
# Step entries
# ------------------------------------------------------------------------------

def _step_cursor_gsd_sync() -> CheckResult:
    return gsd_sync_result(CONFIG_DIR, "--cursor")


STEP_LIST = [Check("cursor-gsd-sync", _step_cursor_gsd_sync)]
