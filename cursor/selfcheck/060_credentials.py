# ------------------------------------------------------------------------------
# Check: the Cursor login file is there
# ------------------------------------------------------------------------------
# The image copies this file to /etc/sbx/selfcheck.d/cursor/; the runner loads it
# after the shared checks.
# ------------------------------------------------------------------------------

from agent_config import login_file_result
from check_result import Check, CheckResult
from cursor_shared import CONFIG_DIR

_LOGIN_HINT = "log in once: run cursor-agent login in this sandbox and open the link on the host"


# ------------------------------------------------------------------------------
# Check entries
# ------------------------------------------------------------------------------

def _check_cursor_credentials() -> CheckResult:
    return login_file_result(CONFIG_DIR / "auth.json", _LOGIN_HINT)


CHECK_LIST = [Check("cursor-credentials", _check_cursor_credentials)]
