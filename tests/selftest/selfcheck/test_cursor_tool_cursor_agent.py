# ------------------------------------------------------------------------------
# Tests of the cursor-agent check
# ------------------------------------------------------------------------------
# A stand-in cursor-agent in tmp_path records the HOME it ran with.
# ------------------------------------------------------------------------------

import os
from pathlib import Path

from helpers import load_agent_check

tool_cursor_agent = load_agent_check("cursor", "010_tool_cursor_agent")


# ------------------------------------------------------------------------------
# Constants and helpers
# ------------------------------------------------------------------------------

def write_cursor_stand_in(folder: Path, home_record_file: Path) -> None:
    stand_in = folder / "cursor-agent"
    stand_in.write_text(
        "#!/bin/sh\n"
        f'printf \'%s\' "$HOME" > "{home_record_file}"\n'
        'echo "$HOME" > "$HOME/cli-config.json"\n'
        'if [ -z "${CURSOR_CONFIG_DIR+x}" ]; then echo v1; else echo config-dir-was-set; fi\n'
    )
    stand_in.chmod(0o755)


def cursor_environment(folder: Path, with_config_dir: bool) -> dict[str, str]:
    environment_map = {"PATH": f"{folder}{os.pathsep}{os.environ['PATH']}", "HOME": str(folder / "home1")}

    if with_config_dir:
        environment_map["CURSOR_CONFIG_DIR"] = str(folder / "state1" / "cursor")

    return environment_map


# ------------------------------------------------------------------------------
# Cursor version
# ------------------------------------------------------------------------------

def test_cursor_version_result_runs_the_cli_with_a_throwaway_home_that_is_gone_afterwards(tmp_path):
    home_record1 = tmp_path / "home-record1"
    write_cursor_stand_in(tmp_path, home_record1)
    environment1 = cursor_environment(tmp_path, False)

    result = tool_cursor_agent.cursor_version_result("v1", environment1)

    seen_home = Path(home_record1.read_text())
    assert result.passed
    assert str(seen_home) != environment1["HOME"]
    assert not seen_home.exists()
    assert not (tmp_path / "home1" / "cli-config.json").exists()


def test_cursor_version_result_hides_the_config_folder_variable_from_the_cli(tmp_path):
    write_cursor_stand_in(tmp_path, tmp_path / "home-record1")
    environment1 = cursor_environment(tmp_path, True)

    result = tool_cursor_agent.cursor_version_result("v1", environment1)

    assert result.passed
    assert environment1["CURSOR_CONFIG_DIR"] == str(tmp_path / "state1" / "cursor")
    assert not (tmp_path / "state1").exists()


def test_cursor_version_result_fails_for_another_version(tmp_path):
    home_record1 = tmp_path / "home-record1"
    write_cursor_stand_in(tmp_path, home_record1)

    result = tool_cursor_agent.cursor_version_result("v2", cursor_environment(tmp_path, False))

    assert not result.passed
    assert "v1" in result.detail
    assert not Path(home_record1.read_text()).exists()


def test_the_check_runs_and_reports_on_cursor_whatever_the_image_state():
    result = tool_cursor_agent.CHECK_LIST[0].function()

    assert "cursor" in (result.detail + result.hint).lower()
