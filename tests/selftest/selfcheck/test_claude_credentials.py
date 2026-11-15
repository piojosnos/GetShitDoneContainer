# ------------------------------------------------------------------------------
# Tests of the Claude login file check
# ------------------------------------------------------------------------------

import paths

from helpers import load_agent_check

credentials = load_agent_check("claude", "060_credentials")


# ------------------------------------------------------------------------------
# Claude login file
# ------------------------------------------------------------------------------

def test_the_check_reads_the_agent_folder_under_the_state_folder():
    assert credentials.CONFIG_DIR == paths.STATE_DIR / "claude"


def test_the_login_hint_names_the_command_that_logs_in():
    assert "sbx-claude" in credentials._LOGIN_HINT
