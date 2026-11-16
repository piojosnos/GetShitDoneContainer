# ------------------------------------------------------------------------------
# Tests of the agent wrappers sbx-claude and sbx-cursor
# ------------------------------------------------------------------------------
# The real scripts run under bash. SBX_INIT_MARKER and SBX_AGENT_BIN_DIR point
# into tmp_path, and a stand-in agent in the agents folder records how it ran.
# ------------------------------------------------------------------------------

import os
import subprocess
import time
from pathlib import Path

import pytest

import paths
from init_helpers import REPO_DIR, write_stand_in

WRAPPER_CASE_LIST = [
    ("claude", "claude/bin/sbx-claude", "sbx-claude"),
]
WRAPPER_IDS = ["claude"]
STAND_IN_BODY = """{
  echo "args=$*"
  echo "command=$(command -v AGENT)"
  echo "path=$PATH"
} > "$RECORD_FILE"
exit 7"""


# ------------------------------------------------------------------------------
# Helpers
# ------------------------------------------------------------------------------

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


def run_wrapper(script_path: str, sandbox: dict, argument_list: list[str]):
    environment = dict(os.environ)
    environment["SBX_INIT_MARKER"] = str(sandbox["marker_file"])
    environment["SBX_AGENT_BIN_DIR"] = str(sandbox["agent_bin_dir"])
    environment["RECORD_FILE"] = str(sandbox["record_file"])

    return subprocess.run(
        ["bash", str(REPO_DIR / script_path), *argument_list],
        env=environment,
        capture_output=True,
        text=True,
        timeout=30,
    )


def default_text(script_path: str, variable_name: str) -> str:
    script_text = (REPO_DIR / script_path).read_text()
    match = re.search(variable_name + r"=\$\{[A-Z_]+:-([^}]*)\}", script_text)
    assert match is not None

    return match.group(1)


# ------------------------------------------------------------------------------
# No marker: refusal
# ------------------------------------------------------------------------------

@pytest.mark.parametrize("agent_name,script_path,wrapper_name", WRAPPER_CASE_LIST, ids=WRAPPER_IDS)
def test_without_the_marker_the_wrapper_refuses_at_once_and_never_starts_the_agent(
    tmp_path, agent_name, script_path, wrapper_name
):
    sandbox = make_sandbox(tmp_path, agent_name)
    started = time.monotonic()

    result = run_wrapper(script_path, sandbox, ["--version"])

    assert result.returncode == 1
    assert result.stderr == f"{wrapper_name}: sbx-init has not passed in this container; run sbx-init first\n"
    assert result.stdout == ""
    assert not sandbox["record_file"].exists()
    assert time.monotonic() - started < 2


# ------------------------------------------------------------------------------
# With the marker: exec the agent from the agents folder
# ------------------------------------------------------------------------------

@pytest.mark.parametrize("agent_name,script_path,wrapper_name", WRAPPER_CASE_LIST, ids=WRAPPER_IDS)
def test_with_the_marker_the_agent_runs_from_the_agents_folder_with_every_argument(
    tmp_path, agent_name, script_path, wrapper_name
):
    sandbox = make_sandbox(tmp_path, agent_name)
    sandbox["marker_file"].write_text("")

    result = run_wrapper(script_path, sandbox, ["--version", "a1"])

    record_line_list = sandbox["record_file"].read_text().splitlines()
    agent_bin_text = str(sandbox["agent_bin_dir"])
    assert result.returncode == 7
    assert result.stderr == ""
    assert record_line_list[0] == "args=--version a1"
    assert record_line_list[1] == f"command={agent_bin_text}/{agent_name}"
    assert record_line_list[2].startswith(f"path={agent_bin_text}{os.pathsep}")
