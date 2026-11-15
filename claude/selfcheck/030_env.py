# ------------------------------------------------------------------------------
# Check: the Claude variables are set
# ------------------------------------------------------------------------------
# The image copies this file to /etc/sbx/selfcheck.d/claude/; the runner loads it
# after the shared checks.
# ------------------------------------------------------------------------------

from check_result import Check, CheckResult
from environment_values import environment_values_result
from paths import STATE_DIR

_CONFIG_DIR = STATE_DIR / "claude"


# ------------------------------------------------------------------------------
# Check entries
# ------------------------------------------------------------------------------

def _check_claude_env() -> CheckResult:
    return environment_values_result({"CLAUDE_CONFIG_DIR": str(_CONFIG_DIR), "DISABLE_UPDATES": "1"})


CHECK_LIST = [Check("claude-env", _check_claude_env)]
