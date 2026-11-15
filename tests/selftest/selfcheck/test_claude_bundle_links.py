# ------------------------------------------------------------------------------
# Tests of the Claude bundle links check
# ------------------------------------------------------------------------------

import paths

from helpers import load_agent_check

bundle_links_check = load_agent_check("claude", "080_bundle_links")


# ------------------------------------------------------------------------------
# Claude bundle links
# ------------------------------------------------------------------------------

def test_the_check_reads_the_agent_folder_under_the_state_folder():
    assert bundle_links_check._CONFIG_DIR == paths.STATE_DIR / "claude"
