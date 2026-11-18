# ------------------------------------------------------------------------------
# Check: the Cursor variables are set
# ------------------------------------------------------------------------------
# The image copies this file to /etc/sbx/selfcheck.d/cursor/; the runner loads it
# after the shared checks.
# ------------------------------------------------------------------------------

from check_result import Check, CheckResult
from cursor_shared import AGENT_CONFIG_DIR
from environment_values import environment_values_result


# ------------------------------------------------------------------------------
# Check entries
# ------------------------------------------------------------------------------

def _check_cursor_env() -> CheckResult:
    return environment_values_result({"CURSOR_CONFIG_DIR": str(AGENT_CONFIG_DIR)})


CHECK_LIST = [Check("cursor-env", _check_cursor_env)]
