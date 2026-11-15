# ------------------------------------------------------------------------------
# Tests of the Claude home link check
# ------------------------------------------------------------------------------

import paths

from helpers import load_agent_check

home_links_check = load_agent_check("claude", "040_home_links")


# ------------------------------------------------------------------------------
# Claude home link
# ------------------------------------------------------------------------------

def test_the_home_link_points_at_the_config_folder_under_the_state_folder():
    assert home_links_check._HOME_LINK == paths.HOME_DIR / ".claude"
    assert home_links_check._CONFIG_DIR == paths.STATE_DIR / "claude"
