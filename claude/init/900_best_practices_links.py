# ------------------------------------------------------------------------------
# Step: link the best-practices clone into the agent config directory
# ------------------------------------------------------------------------------
# The image copies this file to /etc/sbx/init.d/claude/; it runs last, after the
# ownership step.
# ------------------------------------------------------------------------------

from best_practices_linker import link_best_practices
from check_result import Check, CheckResult
from claude_shared import AGENT_CONFIG_DIR, AGENT_NAME
from paths import BEST_PRACTICES_DIR


# ------------------------------------------------------------------------------
# Step entries
# ------------------------------------------------------------------------------

def _step_claude_best_practices_links() -> CheckResult:
    return link_best_practices(AGENT_CONFIG_DIR, BEST_PRACTICES_DIR, AGENT_NAME)


STEP_LIST = [Check("claude-best-practices-links", _step_claude_best_practices_links)]
