# ------------------------------------------------------------------------------
# Tests of the claude check
# ------------------------------------------------------------------------------

from helpers import load_agent_check

tool_claude = load_agent_check("claude", "010_tool_claude")


# ------------------------------------------------------------------------------
# Tool claude
# ------------------------------------------------------------------------------

def test_the_check_runs_and_reports_on_claude_whatever_the_image_state():
    result = tool_claude.CHECK_LIST[0].function()

    assert "claude" in (result.detail + result.hint).lower()
