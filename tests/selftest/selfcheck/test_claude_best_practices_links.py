# ------------------------------------------------------------------------------
# Tests of the Claude best-practices links check
# ------------------------------------------------------------------------------

import paths

from helpers import load_agent_check

best_practices_links_check = load_agent_check("claude", "080_best_practices_links")


# ------------------------------------------------------------------------------
# Claude best-practices links
# ------------------------------------------------------------------------------

def test_the_check_reads_the_agent_folder_under_the_state_folder():
    assert best_practices_links_check.CONFIG_DIR == paths.STATE_DIR / "claude"
