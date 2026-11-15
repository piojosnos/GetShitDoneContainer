# ------------------------------------------------------------------------------
# Tests of the ccusage check
# ------------------------------------------------------------------------------

from helpers import load_agent_check

tool_ccusage = load_agent_check("claude", "020_tool_ccusage")


# ------------------------------------------------------------------------------
# Tool ccusage
# ------------------------------------------------------------------------------

def test_the_check_runs_and_reports_on_ccusage_whatever_the_image_state():
    result = tool_ccusage.CHECK_LIST[0].function()

    assert "ccusage" in (result.detail + result.hint).lower()
