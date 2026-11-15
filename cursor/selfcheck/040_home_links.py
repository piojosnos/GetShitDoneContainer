# ------------------------------------------------------------------------------
# Check: the Cursor home folders link to the Cursor config folder
# ------------------------------------------------------------------------------
# The image copies this file to /etc/sbx/selfcheck.d/cursor/; the runner loads it
# after the shared checks.
# ------------------------------------------------------------------------------

from check_result import Check, CheckResult
from home_links import home_links_result
from paths import HOME_DIR, STATE_DIR

_CONFIG_DIR = STATE_DIR / "cursor"
_HOME_LINK_LIST = [HOME_DIR / ".cursor", HOME_DIR / ".config" / "cursor"]


# ------------------------------------------------------------------------------
# Check entries
# ------------------------------------------------------------------------------

def _check_cursor_home_links() -> CheckResult:
    link_target_list = []

    for home_link in _HOME_LINK_LIST:
        link_target_list.append((home_link, _CONFIG_DIR))

    return home_links_result(link_target_list)


CHECK_LIST = [Check("cursor-home-links", _check_cursor_home_links)]
