# ------------------------------------------------------------------------------
# Check: the agent config directory links the clone's rules and skills
# ------------------------------------------------------------------------------
# The image copies this file to /etc/sbx/selfcheck.d/cursor/; the runner loads it
# after the shared checks.
# ------------------------------------------------------------------------------

from best_practices_links import best_practices_links_result
from check_result import Check, CheckResult
from cursor_shared import AGENT_CONFIG_DIR, AGENT_NAME
from paths import BEST_PRACTICES_DIR


# ------------------------------------------------------------------------------
# Check entries
# ------------------------------------------------------------------------------

def _check_cursor_best_practices_links() -> CheckResult:
    return best_practices_links_result(AGENT_CONFIG_DIR, BEST_PRACTICES_DIR, AGENT_NAME)


CHECK_LIST = [Check("cursor-best-practices-links", _check_cursor_best_practices_links)]
