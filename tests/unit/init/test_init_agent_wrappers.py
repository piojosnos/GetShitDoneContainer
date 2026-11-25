# --------------------------------------------------------------------------------
# Tests of the agent wrappers sbx-claude and sbx-cursor and the sbx-run-agent
# script they share
# --------------------------------------------------------------------------------
# The real scripts run under bash. SBX_INIT_MARKER and SBX_AGENT_BIN_DIR point
# into tmp_path, and a stand-in agent in the agents directory records how it ran.
# The repo's base/bin goes first on the PATH, so the agent wrappers find the repo copy
# of sbx-run-agent ahead of any installed one.
# --------------------------------------------------------------------------------

import os
import re
import subprocess
from pathlib import Path

import pytest

import paths
from init_helpers import REPO_DIR, write_stand_in

AGENT_WRAPPER_CASE_LIST = [
    ("claude", "claude/bin/sbx-claude", "sbx-claude"),
    ("cursor-agent", "cursor/bin/sbx-cursor", "sbx-cursor"),
]
AGENT_WRAPPER_IDS = ["claude", "cursor"]
RUN_AGENT_PATH = "base/bin/sbx-run-agent"
RUN_AGENT_USAGE_TEXT = "Usage: sbx-run-agent AGENT_WRAPPER AGENT [agent arguments]\n"
STAND_IN_BODY = """{
  echo "args=$*"
  echo "command=$(command -v AGENT)"
  echo "path=$PATH"
} > "$RECORD_FILE"
exit 7"""


# --------------------------------------------------------------------------------
# Helpers
# --------------------------------------------------------------------------------

def make_sandbox(tmp_path: Path, agent_name: str) -> dict:
    agent_bin_dir = tmp_path / "agents" / "bin"
    agent_bin_dir.mkdir(parents=True)
    record_file = tmp_path / "record1.txt"
    write_stand_in(agent_bin_dir, agent_name, STAND_IN_BODY.replace("AGENT", agent_name))

    return {
        "agent_bin_dir": agent_bin_dir,
        "record_file": record_file,
        "marker_file": tmp_path / "init-done1",
    }


# --------------------------------------------------------------------------------

def run_agent_wrapper(script_path: str, sandbox: dict, argument_list: list[str]):
    environment = dict(os.environ)
    environment["SBX_INIT_MARKER"] = str(sandbox["marker_file"])
    environment["SBX_AGENT_BIN_DIR"] = str(sandbox["agent_bin_dir"])
    environment["RECORD_FILE"] = str(sandbox["record_file"])
    environment["PATH"] = str(REPO_DIR / "base" / "bin") + os.pathsep + os.environ["PATH"]

    return subprocess.run(
        ["bash", str(REPO_DIR / script_path), *argument_list],
        env=environment,
        capture_output=True,
        text=True,
        timeout=30,
    )


# --------------------------------------------------------------------------------

def code_line_list(script_path: str) -> list[str]:
    kept_line_list = []

    for line in (REPO_DIR / script_path).read_text().splitlines():
        stripped_line = line.strip()
        if stripped_line == "" or stripped_line.startswith("#"):
            continue

        kept_line_list.append(stripped_line)

    return kept_line_list


# --------------------------------------------------------------------------------

def default_text(script_path: str, variable_name: str) -> str:
    script_text = (REPO_DIR / script_path).read_text()
    match = re.search(variable_name + r"=\$\{[A-Z_]+:-([^}]*)\}", script_text)
    assert match is not None

    return match.group(1)


# --------------------------------------------------------------------------------
# No marker: refusal
# --------------------------------------------------------------------------------

@pytest.mark.parametrize("agent_name,script_path,agent_wrapper_name", AGENT_WRAPPER_CASE_LIST, ids=AGENT_WRAPPER_IDS)
def test_without_the_marker_the_agent_wrapper_refuses_at_once_and_never_starts_the_agent(
    tmp_path, agent_name, script_path, agent_wrapper_name
):
    sandbox = make_sandbox(tmp_path, agent_name)

    result = run_agent_wrapper(script_path, sandbox, ["--version"])

    assert result.returncode == 1
    assert result.stderr == f"{agent_wrapper_name}: sbx-init has not passed in this container; run sbx-init first\n"
    assert result.stdout == ""
    assert not sandbox["record_file"].exists()


# --------------------------------------------------------------------------------

@pytest.mark.parametrize("agent_name,script_path,agent_wrapper_name", AGENT_WRAPPER_CASE_LIST, ids=AGENT_WRAPPER_IDS)
def test_a_marker_that_is_a_dir_counts_as_missing(tmp_path, agent_name, script_path, agent_wrapper_name):
    sandbox = make_sandbox(tmp_path, agent_name)
    sandbox["marker_file"].mkdir()

    result = run_agent_wrapper(script_path, sandbox, [])

    assert result.returncode == 1
    assert "has not passed" in result.stderr
    assert not sandbox["record_file"].exists()


# --------------------------------------------------------------------------------
# With the marker: exec the agent from the agents directory
# --------------------------------------------------------------------------------

@pytest.mark.parametrize("agent_name,script_path,agent_wrapper_name", AGENT_WRAPPER_CASE_LIST, ids=AGENT_WRAPPER_IDS)
def test_with_the_marker_the_agent_runs_from_the_agents_dir_with_every_argument(
    tmp_path, agent_name, script_path, agent_wrapper_name
):
    sandbox = make_sandbox(tmp_path, agent_name)
    sandbox["marker_file"].write_text("")

    result = run_agent_wrapper(script_path, sandbox, ["--version", "a1"])

    record_line_list = sandbox["record_file"].read_text().splitlines()
    agent_bin_text = str(sandbox["agent_bin_dir"])
    assert result.returncode == 7
    assert result.stderr == ""
    assert record_line_list[0] == "args=--version a1"
    assert record_line_list[1] == f"command={agent_bin_text}/{agent_name}"
    assert record_line_list[2].startswith(f"path={agent_bin_text}{os.pathsep}")


# --------------------------------------------------------------------------------
# The shell literals equal the Python paths
# --------------------------------------------------------------------------------

def test_the_sbx_run_agent_defaults_equal_the_python_paths():
    assert default_text(RUN_AGENT_PATH, "initMarker") == str(paths.INIT_MARKER_FILE)
    assert default_text(RUN_AGENT_PATH, "agentBinDir") == str(paths.AGENT_BIN_DIR)


# --------------------------------------------------------------------------------
# Symmetry
# --------------------------------------------------------------------------------

def test_the_two_agent_wrappers_are_the_same_script_apart_from_the_agent_names():
    claude_text = (REPO_DIR / "claude/bin/sbx-claude").read_text()
    cursor_text = (REPO_DIR / "cursor/bin/sbx-cursor").read_text()

    claude_text = claude_text.replace("cursor-agent", "AGENT").replace("claude", "AGENT").replace("Claude", "AGENT")
    cursor_text = cursor_text.replace("cursor-agent", "AGENT").replace("cursor", "AGENT").replace("Cursor", "AGENT")

    assert claude_text == cursor_text


# --------------------------------------------------------------------------------
# The agent wrappers are one exec line over sbx-run-agent
# --------------------------------------------------------------------------------

@pytest.mark.parametrize("agent_name,script_path,agent_wrapper_name", AGENT_WRAPPER_CASE_LIST, ids=AGENT_WRAPPER_IDS)
def test_the_agent_wrapper_code_is_set_and_one_exec_line(agent_name, script_path, agent_wrapper_name):
    exec_line = f'exec sbx-run-agent {agent_wrapper_name} {agent_name} "$@"'

    assert code_line_list(script_path) == ["set -eu", exec_line]


# --------------------------------------------------------------------------------
# sbx-run-agent called directly
# --------------------------------------------------------------------------------

def test_the_refusal_names_the_first_argument(tmp_path):
    sandbox = make_sandbox(tmp_path, "agent1")

    result = run_agent_wrapper(RUN_AGENT_PATH, sandbox, ["sbx-x1", "agent1"])

    assert result.returncode == 1
    assert result.stderr == "sbx-x1: sbx-init has not passed in this container; run sbx-init first\n"
    assert not sandbox["record_file"].exists()


# --------------------------------------------------------------------------------

@pytest.mark.parametrize("argument_list", [[], ["sbx-x1"]], ids=["none", "one"])
def test_fewer_than_two_arguments_print_the_usage_line_and_exit_2(tmp_path, argument_list):
    sandbox = make_sandbox(tmp_path, "agent1")
    sandbox["marker_file"].write_text("")

    result = run_agent_wrapper(RUN_AGENT_PATH, sandbox, argument_list)

    assert result.returncode == 2
    assert result.stderr == RUN_AGENT_USAGE_TEXT
    assert result.stdout == ""
    assert not sandbox["record_file"].exists()


# --------------------------------------------------------------------------------

def test_sbx_run_agent_names_no_agent():
    script_text = (REPO_DIR / RUN_AGENT_PATH).read_text().lower()

    assert "claude" not in script_text
    assert "cursor" not in script_text


# --------------------------------------------------------------------------------
# The image puts the agent wrappers and sbx-run-agent in one directory on the PATH
# --------------------------------------------------------------------------------

def test_the_dockerfiles_copy_the_bin_dirs_into_usr_local_bin():
    base_text = (REPO_DIR / "base/Dockerfile").read_text()

    assert "COPY --chmod=755 base/bin/ /usr/local/bin/" in base_text

    for agent_dir in ["claude", "cursor"]:
        agent_text = (REPO_DIR / agent_dir / "Dockerfile").read_text()

        assert f"COPY --chmod=755 {agent_dir}/bin/ /usr/local/bin/" in agent_text
