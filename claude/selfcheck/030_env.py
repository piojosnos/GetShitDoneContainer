# ------------------------------------------------------------------------------
# Check: the Claude variables are set
# ------------------------------------------------------------------------------
# The image copies this file to /etc/sbx/selfcheck.d/claude/; the runner loads it
# after the shared checks.
# ------------------------------------------------------------------------------

from check_result import Check, CheckResult
from claude_shared import AGENT_CONFIG_DIR
from environment_values import environment_values_result


# ------------------------------------------------------------------------------
# Check entries
# ------------------------------------------------------------------------------

def _check_claude_env() -> CheckResult:
    return environment_values_result({"CLAUDE_CONFIG_DIR": str(AGENT_CONFIG_DIR), "DISABLE_UPDATES": "1"})


CHECK_LIST = [Check("claude-env", _check_claude_env)]
