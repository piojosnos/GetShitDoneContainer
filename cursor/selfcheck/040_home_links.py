# ------------------------------------------------------------------------------
# Check: the Cursor home directories link to the agent config directory
# ------------------------------------------------------------------------------
# The image copies this file to /etc/sbx/selfcheck.d/cursor/; the runner loads it
# after the shared checks.
# ------------------------------------------------------------------------------

from check_result import Check, CheckResult
from cursor_shared import CONFIG_DIR
from home_links import home_links_result
from paths import HOME_DIR

_HOME_LINK_LIST = [HOME_DIR / ".cursor", HOME_DIR / ".config" / "cursor"]


# ------------------------------------------------------------------------------
# Check entries
# ------------------------------------------------------------------------------

def _check_cursor_home_links() -> CheckResult:
    link_target_list = []

    for home_link in _HOME_LINK_LIST:
        link_target_list.append((home_link, CONFIG_DIR))

    return home_links_result(link_target_list)


CHECK_LIST = [Check("cursor-home-links", _check_cursor_home_links)]
