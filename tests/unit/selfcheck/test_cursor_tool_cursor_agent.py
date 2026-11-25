# --------------------------------------------------------------------------------
# Tests of the cursor-agent check
# --------------------------------------------------------------------------------
# A stand-in cursor-agent in tmp_path records the HOME it ran with.
# --------------------------------------------------------------------------------

import os
from pathlib import Path

from helpers import load_agent_check, write_stand_in

tool_cursor_agent = load_agent_check("cursor", "010_tool_cursor_agent")


# --------------------------------------------------------------------------------
# Constants and helpers
# --------------------------------------------------------------------------------

def write_cursor_stand_in(dir_path: Path, home_record_file: Path) -> None:
    stand_in = dir_path / "cursor-agent"
    stand_in.write_text(
        "#!/bin/sh\n"
        f'printf \'%s\' "$HOME" > "{home_record_file}"\n'
        'echo "$HOME" > "$HOME/cli-config.json"\n'
        'if [ -z "${CURSOR_CONFIG_DIR+x}" ]; then echo v1; else echo config-dir-was-set; fi\n'
    )
    stand_in.chmod(0o755)


# --------------------------------------------------------------------------------

def cursor_environment(dir_path: Path, with_config_dir: bool) -> dict[str, str]:
    environment_map = {"PATH": f"{dir_path}{os.pathsep}{os.environ['PATH']}", "HOME": str(dir_path / "home1")}

    if with_config_dir:
        environment_map["CURSOR_CONFIG_DIR"] = str(dir_path / "state1" / "cursor")

    return environment_map


# --------------------------------------------------------------------------------
# Cursor version
# --------------------------------------------------------------------------------

def test_cursor_version_result_runs_the_cli_with_a_throwaway_home_that_is_gone_afterwards(tmp_path):
    home_record1 = tmp_path / "home-record1"
    write_cursor_stand_in(tmp_path, home_record1)
    environment1 = cursor_environment(tmp_path, False)

    result = tool_cursor_agent.cursor_version_result("v1", environment_map=environment1)

    seen_home = Path(home_record1.read_text())
    assert result.passed
    assert str(seen_home) != environment1["HOME"]
    assert not seen_home.exists()
    assert not (tmp_path / "home1" / "cli-config.json").exists()


# --------------------------------------------------------------------------------

def test_cursor_version_result_hides_the_config_dir_variable_from_the_cli(tmp_path):
    write_cursor_stand_in(tmp_path, tmp_path / "home-record1")
    environment1 = cursor_environment(tmp_path, True)

    result = tool_cursor_agent.cursor_version_result("v1", environment_map=environment1)

    assert result.passed
    assert environment1["CURSOR_CONFIG_DIR"] == str(tmp_path / "state1" / "cursor")
    assert not (tmp_path / "state1").exists()


# --------------------------------------------------------------------------------

def test_cursor_version_result_fails_for_another_version(tmp_path):
    home_record1 = tmp_path / "home-record1"
    write_cursor_stand_in(tmp_path, home_record1)

    result = tool_cursor_agent.cursor_version_result("v2", environment_map=cursor_environment(tmp_path, False))

    assert not result.passed
    assert "v1" in result.detail
    assert not Path(home_record1.read_text()).exists()


# --------------------------------------------------------------------------------

def test_the_check_runs_and_reports_on_cursor_whatever_the_image_state():
    result = tool_cursor_agent.CHECK_LIST[0].function()

    assert "cursor" in (result.detail + result.hint).lower()


# --------------------------------------------------------------------------------

def test_cursor_version_result_finds_a_cursor_agent_that_is_only_in_the_agents_dir(tmp_path):
    agent_bin1 = tmp_path / "agent-bin1"
    agent_bin1.mkdir()
    home_record1 = tmp_path / "home-record1"
    write_cursor_stand_in(agent_bin1, home_record1)
    environment1 = {"PATH": "/nowhere1", "HOME": str(tmp_path / "home1")}

    result = tool_cursor_agent.cursor_version_result("v1", agent_bin1, environment1)

    seen_home = Path(home_record1.read_text())
    assert result.passed
    assert str(agent_bin1 / "cursor-agent") in result.detail
    assert str(seen_home) != environment1["HOME"]
    assert not seen_home.exists()


# --------------------------------------------------------------------------------
# Cursor off the PATH
# --------------------------------------------------------------------------------

def test_cursor_off_path_fails_when_cursor_agent_is_also_in_another_path_dir(tmp_path, bin1):
    other1 = tmp_path / "other1"
    other1.mkdir()
    write_stand_in(bin1, "cursor-agent", "echo v1")
    write_stand_in(other1, "cursor-agent", "echo v1")

    result = tool_cursor_agent.cursor_off_path_result(bin1, {"PATH": f"{bin1}{os.pathsep}{other1}"})

    assert not result.passed
    assert str(other1 / "cursor-agent") in result.detail


# --------------------------------------------------------------------------------

def test_cursor_off_path_passes_when_cursor_agent_is_only_in_the_agents_dir(bin1):
    write_stand_in(bin1, "cursor-agent", "echo v1")

    result = tool_cursor_agent.cursor_off_path_result(bin1, {"PATH": f"{bin1}{os.pathsep}/nowhere1"})

    assert result.passed


# --------------------------------------------------------------------------------

def test_the_cursor_list_is_tool_cursor_agent_then_cursor_off_path():
    assert [check.name for check in tool_cursor_agent.CHECK_LIST] == ["tool-cursor-agent", "cursor-off-path"]
