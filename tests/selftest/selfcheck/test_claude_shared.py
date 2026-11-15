# ------------------------------------------------------------------------------
# Tests of the library the Claude checks share
# ------------------------------------------------------------------------------
# The library reaches sys.path through the pytest pythonpath setting in
# pyproject.toml, the way the launcher puts the image's agents folder there.
# ------------------------------------------------------------------------------

import claude_shared
import paths


# ------------------------------------------------------------------------------
# Claude shared library
# ------------------------------------------------------------------------------

def test_the_config_folder_is_the_agent_folder_under_the_state_folder():
    assert claude_shared.CONFIG_DIR == paths.STATE_DIR / "claude"
