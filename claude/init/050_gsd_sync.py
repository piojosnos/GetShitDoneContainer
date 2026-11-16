# ------------------------------------------------------------------------------
# Step: sync the image's GSD into the Claude config folder
# ------------------------------------------------------------------------------
# The image copies this file to /etc/sbx/init.d/claude/; the runner sorts it in
# by file name.
# ------------------------------------------------------------------------------

from check_result import Check, CheckResult
from claude_shared import CONFIG_DIR
from gsd_sync import gsd_sync_result


# ------------------------------------------------------------------------------
# Step entries
# ------------------------------------------------------------------------------

def _step_claude_gsd_sync() -> CheckResult:
    return gsd_sync_result(CONFIG_DIR, "--claude")


STEP_LIST = [Check("claude-gsd-sync", _step_claude_gsd_sync)]
