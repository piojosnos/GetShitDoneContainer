# ------------------------------------------------------------------------------
# Check: ~/.claude links to the agent config directory
# ------------------------------------------------------------------------------
# The image copies this file to /etc/sbx/selfcheck.d/claude/; the runner loads it
# after the shared checks.
# ------------------------------------------------------------------------------

from check_result import Check, CheckResult
from claude_shared import CONFIG_DIR
from home_links import home_links_result
from paths import HOME_DIR

_HOME_LINK = HOME_DIR / ".claude"


# ------------------------------------------------------------------------------
# Check entries
# ------------------------------------------------------------------------------

def _check_claude_home_links() -> CheckResult:
    return home_links_result([(_HOME_LINK, CONFIG_DIR)])


CHECK_LIST = [Check("claude-home-links", _check_claude_home_links)]
