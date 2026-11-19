# ------------------------------------------------------------------------------
# Tests of the Cursor GSD sync check
# ------------------------------------------------------------------------------

import paths

from helpers import load_agent_check

gsd_synced = load_agent_check("cursor", "070_gsd_synced")


# ------------------------------------------------------------------------------
# Cursor GSD sync
# ------------------------------------------------------------------------------

def test_the_check_reads_the_agent_dir_under_the_state_dir():
    assert gsd_synced.AGENT_CONFIG_DIR == paths.STATE_DIR / "cursor"
