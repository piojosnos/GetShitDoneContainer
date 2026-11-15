# ------------------------------------------------------------------------------
# Check: the synced GSD is the pinned version
# ------------------------------------------------------------------------------
# The image copies this file to /etc/sbx/selfcheck.d/claude/; the runner loads it
# after the shared checks.
# ------------------------------------------------------------------------------

from agent_config import gsd_synced_result
from check_result import Check, CheckResult
from paths import STATE_DIR

_CONFIG_DIR = STATE_DIR / "claude"


# ------------------------------------------------------------------------------
# Check entries
# ------------------------------------------------------------------------------

def _check_claude_gsd_synced() -> CheckResult:
    return gsd_synced_result(_CONFIG_DIR)


CHECK_LIST = [Check("claude-gsd-synced", _check_claude_gsd_synced)]
