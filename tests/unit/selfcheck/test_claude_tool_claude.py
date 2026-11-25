# --------------------------------------------------------------------------------
# Tests of the claude checks
# --------------------------------------------------------------------------------
# A stand-in claude in tmp_path stands for the one in the agents directory.
# --------------------------------------------------------------------------------

import os

from helpers import load_agent_check, write_stand_in

tool_claude = load_agent_check("claude", "010_tool_claude")


# --------------------------------------------------------------------------------
# Tool claude
# --------------------------------------------------------------------------------

def test_the_check_runs_and_reports_on_claude_whatever_the_image_state():
    result = tool_claude.CHECK_LIST[0].function()

    assert "claude" in (result.detail + result.hint).lower()


def test_claude_version_result_finds_a_claude_that_is_only_in_the_agents_dir(bin1):
    write_stand_in(bin1, "claude", 'echo "1.2.3 (Claude Code)"')

    result = tool_claude.claude_version_result("1.2.3", bin1, {"PATH": "/nowhere1"})

    assert result.passed
    assert str(bin1 / "claude") in result.detail


def test_claude_version_result_fails_for_another_version(bin1):
    write_stand_in(bin1, "claude", 'echo "1.2.3 (Claude Code)"')

    result = tool_claude.claude_version_result("2.0.0", bin1, {"PATH": "/nowhere1"})

    assert not result.passed
    assert "1.2.3" in result.detail


def test_claude_off_path_fails_when_claude_is_also_in_another_path_dir(tmp_path, bin1):
    other1 = tmp_path / "other1"
    other1.mkdir()
    write_stand_in(bin1, "claude", "echo v1")
    write_stand_in(other1, "claude", "echo v1")

    result = tool_claude.claude_off_path_result(bin1, {"PATH": f"{bin1}{os.pathsep}{other1}"})

    assert not result.passed
    assert str(other1 / "claude") in result.detail


def test_claude_off_path_passes_when_claude_is_only_in_the_agents_dir(bin1):
    write_stand_in(bin1, "claude", "echo v1")

    result = tool_claude.claude_off_path_result(bin1, {"PATH": f"{bin1}{os.pathsep}/nowhere1"})

    assert result.passed


def test_the_claude_list_is_tool_claude_then_claude_off_path():
    assert [check.name for check in tool_claude.CHECK_LIST] == ["tool-claude", "claude-off-path"]
