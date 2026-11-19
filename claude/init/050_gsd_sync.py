# ------------------------------------------------------------------------------
# Step: sync the image's GSD into the agent config directory
# ------------------------------------------------------------------------------
# The image copies this file to /etc/sbx/init.d/claude/; the runner sorts it in
# by file name.
# ------------------------------------------------------------------------------

from pathlib import Path
from typing import Callable

from check_result import Check, CheckResult
from claude_shared import AGENT_CONFIG_DIR
from gsd_sync import gsd_sync_result


# ------------------------------------------------------------------------------
# Step entries
# ------------------------------------------------------------------------------

def _step_claude_gsd_sync(
    sync_function: Callable[[Path, str], CheckResult] = gsd_sync_result,
) -> CheckResult:
    return sync_function(AGENT_CONFIG_DIR, "--claude")


STEP_LIST = [Check("claude-gsd-sync", _step_claude_gsd_sync)]
