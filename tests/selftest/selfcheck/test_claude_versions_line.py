# ------------------------------------------------------------------------------
# Tests of the Claude versions line check
# ------------------------------------------------------------------------------

from helpers import load_agent_check

versions_line = load_agent_check("claude", "120_versions_line")


# ------------------------------------------------------------------------------
# Claude versions line
# ------------------------------------------------------------------------------

def test_the_check_runs_and_reports_on_claude_whatever_the_image_state():
    result = versions_line.CHECK_LIST[0].function()

    assert "claude" in (result.detail + result.hint).lower()
