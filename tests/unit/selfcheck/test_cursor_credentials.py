# ------------------------------------------------------------------------------
# Tests of the Cursor login file check
# ------------------------------------------------------------------------------

import paths

from helpers import load_agent_check

credentials = load_agent_check("cursor", "060_credentials")


# ------------------------------------------------------------------------------
# Cursor login file
# ------------------------------------------------------------------------------

def test_the_check_reads_the_agent_dir_under_the_state_dir():
    assert credentials.AGENT_CONFIG_DIR == paths.STATE_DIR / "cursor"


def test_the_login_hint_names_the_command_that_logs_in():
    assert "cursor-agent login" in credentials._LOGIN_HINT
