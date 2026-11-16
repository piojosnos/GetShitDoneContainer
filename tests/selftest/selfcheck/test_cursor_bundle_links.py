# ------------------------------------------------------------------------------
# Tests of the Cursor bundle links check
# ------------------------------------------------------------------------------

import paths

from helpers import load_agent_check

bundle_links_check = load_agent_check("cursor", "080_bundle_links")


# ------------------------------------------------------------------------------
# Cursor bundle links
# ------------------------------------------------------------------------------

def test_the_check_reads_the_agent_folder_under_the_state_folder():
    assert bundle_links_check.CONFIG_DIR == paths.STATE_DIR / "cursor"
