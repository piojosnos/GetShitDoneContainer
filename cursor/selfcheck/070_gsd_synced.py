# ------------------------------------------------------------------------------
# Check: the synced GSD is the pinned version
# ------------------------------------------------------------------------------
# The image copies this file to /etc/sbx/selfcheck.d/cursor/; the runner loads it
# after the shared checks.
# ------------------------------------------------------------------------------

from agent_config import gsd_synced_result
from check_result import Check, CheckResult
from cursor_shared import CONFIG_DIR


# ------------------------------------------------------------------------------
# Check entries
# ------------------------------------------------------------------------------

def _check_cursor_gsd_synced() -> CheckResult:
    return gsd_synced_result(CONFIG_DIR)


CHECK_LIST = [Check("cursor-gsd-synced", _check_cursor_gsd_synced)]
