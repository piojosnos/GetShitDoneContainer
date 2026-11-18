# ------------------------------------------------------------------------------
# Tests of the Cursor home link check
# ------------------------------------------------------------------------------

import paths

from helpers import load_agent_check

home_links_check = load_agent_check("cursor", "040_home_links")


# ------------------------------------------------------------------------------
# Cursor home links
# ------------------------------------------------------------------------------

def test_both_home_links_point_at_the_config_dir_under_the_state_dir():
    assert home_links_check._HOME_LINK_LIST == [paths.HOME_DIR / ".cursor", paths.HOME_DIR / ".config" / "cursor"]
    assert home_links_check.CONFIG_DIR == paths.STATE_DIR / "cursor"
