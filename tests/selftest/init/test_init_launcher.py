# ------------------------------------------------------------------------------
# Tests of the sbx-init launcher
# ------------------------------------------------------------------------------
# The launcher runs from a copy of the image layout in a temp folder, with the
# paths it reads pointed into that folder. Nothing here touches /home/sandbox or
# /etc/sbx.
# ------------------------------------------------------------------------------

import os
import shutil
import subprocess
import sys
from pathlib import Path

import pytest

from init_helpers import REPO_DIR

AGENT_STEP_TEXT = """from check_result import Check, passed


def step_step1():
    return passed("detail_step1")


STEP_LIST = [Check("step1", step_step1)]
"""
PATH_OVERRIDE_TEMPLATE = """
STATE_DIR = Path({state_dir!r})
AGENT_STEPS_DIR = Path({agent_steps_dir!r})
INIT_MARKER_FILE = Path({marker_file!r})
INIT_LOCK_FILE = Path({lock_file!r})
"""


# ------------------------------------------------------------------------------
# Fixtures
# ------------------------------------------------------------------------------

@pytest.fixture
def layout1(tmp_path) -> dict[str, Path]:
    init_dir = tmp_path / "lib" / "sbx-init"
    selfcheck_dir = tmp_path / "lib" / "sbx-selfcheck"
    (init_dir / "steps").mkdir(parents=True)
    selfcheck_dir.mkdir(parents=True)

    shutil.copy(REPO_DIR / "base" / "init" / "sbx-init", init_dir / "sbx-init")

    for module_path in (REPO_DIR / "base" / "init").glob("*.py"):
        shutil.copy(module_path, init_dir / module_path.name)

    for step_path in (REPO_DIR / "base" / "init" / "steps").glob("*.py"):
        shutil.copy(step_path, init_dir / "steps" / step_path.name)

    for module_path in (REPO_DIR / "base" / "selfcheck").glob("*.py"):
        shutil.copy(module_path, selfcheck_dir / module_path.name)

    layout = {
        "launcher": init_dir / "sbx-init",
        "state": tmp_path / "state1",
        "agent_steps": tmp_path / "init.d",
        "marker": tmp_path / "home1" / ".sbx-init-done",
        "lock": tmp_path / "home1" / ".sbx-init.lock",
    }
    layout["marker"].parent.mkdir()
    (layout["agent_steps"] / "agent1").mkdir(parents=True)
    (layout["agent_steps"] / "agent1" / "020_step1.py").write_text(AGENT_STEP_TEXT)

    with open(selfcheck_dir / "paths.py", "a") as paths_file:
        paths_file.write(
            PATH_OVERRIDE_TEMPLATE.format(
                state_dir=str(layout["state"]),
                agent_steps_dir=str(layout["agent_steps"]),
                marker_file=str(layout["marker"]),
                lock_file=str(layout["lock"]),
            )
        )

    return layout


def run_launcher(layout: dict[str, Path], argument_list: list[str], state_dirs_text: str = "") -> subprocess.CompletedProcess:
    return subprocess.run(
        [sys.executable, "-I", str(layout["launcher"])] + argument_list,
        capture_output=True,
        text=True,
        stdin=subprocess.DEVNULL,
        timeout=60,
        env={"PATH": os.environ["PATH"], "SBX_STATE_DIRS": state_dirs_text},
    )


# ------------------------------------------------------------------------------
# Usage error and the end-to-end run
# ------------------------------------------------------------------------------

def test_an_argument_exits_two_with_the_usage_line_and_touches_no_file(layout1):
    completed = run_launcher(layout1, ["extra"])

    assert completed.returncode == 2
    assert completed.stdout == ""
    assert completed.stderr == "Usage: sbx-init (no arguments)\n"
    assert not layout1["marker"].exists()
    assert not layout1["lock"].exists()
    assert not layout1["state"].exists()


def test_one_run_makes_the_state_folders_runs_the_agent_step_gives_state_back_and_writes_the_marker(layout1):
    completed = run_launcher(layout1, [], "cache/npm claude")

    state1 = layout1["state"]
    assert completed.stderr == ""
    assert completed.stdout.splitlines() == [
        f"OK: state-folders: shell, gh, git, cache/npm, claude exist under {state1}",
        "OK: step1: detail_step1",
        "OK: state-owner: 0 paths given back to sandbox",
        "sbx-init: 3 steps passed; run sbx-selfcheck to check the sandbox",
    ]
    assert completed.returncode == 0
    assert layout1["marker"].is_file()

    for name in ["shell", "gh", "git", "cache/npm", "claude"]:
        assert (state1 / name).is_dir()
