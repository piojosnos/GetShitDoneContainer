# ------------------------------------------------------------------------------
# Check: the agent config directory links the clone's rules and skills
# ------------------------------------------------------------------------------
# The image copies this file to /etc/sbx/selfcheck.d/claude/; the runner loads it
# after the shared checks.
# ------------------------------------------------------------------------------

from best_practices_links import best_practices_links_result
from check_result import Check, CheckResult
from claude_shared import AGENT_CONFIG_DIR
from paths import BEST_PRACTICES_DIR


# ------------------------------------------------------------------------------
# Check entries
# ------------------------------------------------------------------------------

def _check_claude_best_practices_links() -> CheckResult:
    return best_practices_links_result(AGENT_CONFIG_DIR, BEST_PRACTICES_DIR, True)


CHECK_LIST = [Check("claude-best-practices-links", _check_claude_best_practices_links)]
