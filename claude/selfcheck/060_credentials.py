# ------------------------------------------------------------------------------
# Check: the Claude login file is there
# ------------------------------------------------------------------------------
# The image copies this file to /etc/sbx/selfcheck.d/claude/; the runner loads it
# after the shared checks.
# ------------------------------------------------------------------------------

from agent_config import login_file_result
from check_result import Check, CheckResult
from claude_shared import CONFIG_DIR

_LOGIN_HINT = "log in once: run sbx-claude in this sandbox and follow the login"


# ------------------------------------------------------------------------------
# Check entries
# ------------------------------------------------------------------------------

def _check_claude_credentials() -> CheckResult:
    return login_file_result(CONFIG_DIR / ".credentials.json", _LOGIN_HINT)


CHECK_LIST = [Check("claude-credentials", _check_claude_credentials)]
