# ------------------------------------------------------------------------------
# Check: the config folder links the clone's skills
# ------------------------------------------------------------------------------
# The image copies this file to /etc/sbx/selfcheck.d/cursor/; the runner loads it
# after the shared checks.
# ------------------------------------------------------------------------------

from best_practices_links import best_practices_links_result
from check_result import Check, CheckResult
from cursor_shared import CONFIG_DIR
from paths import BEST_PRACTICES_DIR


# ------------------------------------------------------------------------------
# Check entries
# ------------------------------------------------------------------------------

def _check_cursor_best_practices_links() -> CheckResult:
    return best_practices_links_result(CONFIG_DIR, BEST_PRACTICES_DIR, False)


CHECK_LIST = [Check("cursor-best-practices-links", _check_cursor_best_practices_links)]
