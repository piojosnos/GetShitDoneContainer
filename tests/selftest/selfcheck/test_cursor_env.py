# ------------------------------------------------------------------------------
# Tests of the Cursor environment check
# ------------------------------------------------------------------------------

import paths

from helpers import load_agent_check

agent_env = load_agent_check("cursor", "030_env")


# ------------------------------------------------------------------------------
# Cursor environment
# ------------------------------------------------------------------------------

def test_the_config_folder_is_the_agent_folder_under_the_state_folder():
    assert agent_env.CONFIG_DIR == paths.STATE_DIR / "cursor"
