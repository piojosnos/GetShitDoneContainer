# ------------------------------------------------------------------------------
# Tests of the Cursor best-practices links check
# ------------------------------------------------------------------------------

import paths

from helpers import load_agent_check

best_practices_links_check = load_agent_check("cursor", "080_best_practices_links")


# ------------------------------------------------------------------------------
# Cursor best-practices links
# ------------------------------------------------------------------------------

def test_the_check_reads_the_agent_dir_under_the_state_dir():
    assert best_practices_links_check.AGENT_CONFIG_DIR == paths.STATE_DIR / "cursor"
