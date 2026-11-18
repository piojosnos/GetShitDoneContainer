# ------------------------------------------------------------------------------
# Tests of the Cursor versions line check
# ------------------------------------------------------------------------------

from helpers import load_agent_check

versions_line = load_agent_check("cursor", "120_versions_line")


# ------------------------------------------------------------------------------
# Cursor versions line
# ------------------------------------------------------------------------------

def test_the_check_runs_and_reports_on_cursor_whatever_the_image_state():
    result = versions_line.CHECK_LIST[0].function()

    assert "cursor" in (result.detail + result.hint).lower()
