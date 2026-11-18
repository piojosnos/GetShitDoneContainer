# ------------------------------------------------------------------------------
# Tests of the library the Cursor checks share
# ------------------------------------------------------------------------------
# The library reaches sys.path through the pytest pythonpath setting in
# pyproject.toml, the way the launcher puts the image's agents directory there.
# ------------------------------------------------------------------------------

import cursor_shared
import paths


# ------------------------------------------------------------------------------
# Cursor shared library
# ------------------------------------------------------------------------------

def test_the_config_dir_is_the_agent_dir_under_the_state_dir():
    assert cursor_shared.CONFIG_DIR == paths.STATE_DIR / "cursor"
