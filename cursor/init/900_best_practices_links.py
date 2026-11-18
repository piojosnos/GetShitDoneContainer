# ------------------------------------------------------------------------------
# Step: link the best-practices clone into the agent config directory
# ------------------------------------------------------------------------------
# Cursor gets the skills only, because it reads global rules only from .mdc
# files. The image copies this file to /etc/sbx/init.d/cursor/; it runs last,
# after the ownership step.
# ------------------------------------------------------------------------------

from best_practices_link import link_best_practices
from check_result import Check, CheckResult
from cursor_shared import AGENT_CONFIG_DIR
from paths import BEST_PRACTICES_DIR


# ------------------------------------------------------------------------------
# Step entries
# ------------------------------------------------------------------------------

def _step_cursor_best_practices_links() -> CheckResult:
    return link_best_practices(AGENT_CONFIG_DIR, BEST_PRACTICES_DIR, False)


STEP_LIST = [Check("cursor-best-practices-links", _step_cursor_best_practices_links)]
