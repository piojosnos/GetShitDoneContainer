# ------------------------------------------------------------------------------
# Tests of the sbx-init launcher
# ------------------------------------------------------------------------------
# The launcher runs from a copy of the image layout in a temp directory, with the
# paths it reads pointed into that directory. Nothing here touches /home/sandbox or
# /etc/sbx. One test interrupts a real run while a stand-in installer sleeps.
# ------------------------------------------------------------------------------

import fcntl
import os
import shutil
import signal
import subprocess
import sys
import time
from pathlib import Path

import pytest

from init_helpers import REPO_DIR, process_is_gone, write_stand_in

AGENT_STEP_TEXT = """from check_result import Check, passed


def step_step1():
    return passed("detail_step1")


STEP_LIST = [Check("step1", step_step1)]
"""
SLEEPING_STEP_TEMPLATE = """from pathlib import Path

from check_result import Check
from gsd_sync import gsd_sync_result


def step_sync1():
    return gsd_sync_result(Path({config_dir!r}), "--claude", {installer_name!r}, log_dir=Path({log_dir!r}))


STEP_LIST = [Check("sync1", step_sync1)]
"""
SLEEPING_INSTALLER_BODY = """sleep 60 &
echo $! > "$STAND_IN_GRANDCHILD_FILE"
echo $$ > "$STAND_IN_PID_FILE"
wait
"""
INTERRUPTED_LINE = "sbx-init: interrupted; run sbx-init again"
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


def test_one_run_makes_the_state_dirs_runs_the_agent_step_gives_state_back_and_writes_the_marker(layout1):
    completed = run_launcher(layout1, [], "cache/npm claude")

    state1 = layout1["state"]
    assert completed.stderr == ""
    assert completed.stdout.splitlines() == [
        f"OK: state-dirs: shell, gh, git, cache/npm, claude exist under {state1}",
        "OK: step1: detail_step1",
        "OK: state-owner: 0 paths given back to sandbox",
        "sbx-init: 3 steps passed; run sbx-selfcheck to check the sandbox",
    ]
    assert completed.returncode == 0
    assert layout1["marker"].is_file()

    for name in ["shell", "gh", "git", "cache/npm", "claude"]:
        assert (state1 / name).is_dir()


# ------------------------------------------------------------------------------
# Interruption
# ------------------------------------------------------------------------------

def wait_for_text_file(text_file: Path, deadline_seconds: float) -> str:
    deadline = time.monotonic() + deadline_seconds

    while time.monotonic() < deadline:
        if text_file.is_file() and text_file.read_text().strip():
            return text_file.read_text().strip()

        time.sleep(0.05)

    raise AssertionError(f"{text_file} was not written within {deadline_seconds} s")


def kill_group_quietly(group_id: int) -> None:
    try:
        os.killpg(group_id, signal.SIGKILL)
    except (ProcessLookupError, PermissionError):
        pass


@pytest.mark.parametrize(
    "signal_number",
    [signal.SIGINT, signal.SIGHUP, signal.SIGTERM],
    ids=["sigint", "sighup", "sigterm"],
)
def test_an_interrupted_run_stops_the_installer_and_its_child_drops_the_log_and_frees_the_lock(
    layout1, tmp_path, signal_number
):
    bin1 = tmp_path / "bin1"
    logs1 = tmp_path / "logs1"
    bin1.mkdir()
    logs1.mkdir()
    write_stand_in(bin1, "installer1", SLEEPING_INSTALLER_BODY)
    (layout1["agent_steps"] / "agent1" / "020_step1.py").write_text(
        SLEEPING_STEP_TEMPLATE.format(
            config_dir=str(tmp_path / "config1"), installer_name="installer1", log_dir=str(logs1)
        )
    )
    pid_file = tmp_path / "pid1.txt"
    grandchild_file = tmp_path / "grandchild1.txt"
    launcher = subprocess.Popen(
        [sys.executable, "-I", str(layout1["launcher"])],
        stdin=subprocess.DEVNULL,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        text=True,
        env={
            "PATH": f"{bin1}{os.pathsep}{os.environ['PATH']}",
            "SBX_STATE_DIRS": "",
            "STAND_IN_PID_FILE": str(pid_file),
            "STAND_IN_GRANDCHILD_FILE": str(grandchild_file),
        },
    )
    installer_id = 0

    try:
        installer_id = int(wait_for_text_file(pid_file, 10))
        grandchild_id = int(wait_for_text_file(grandchild_file, 10))
        launcher.send_signal(signal_number)
        stdout_text, stderr_text = launcher.communicate(timeout=20)

        assert launcher.returncode == 130
        assert stderr_text.splitlines()[-1] == INTERRUPTED_LINE
        assert "OK: state-dirs:" in stdout_text
        assert "steps passed" not in stdout_text
        assert process_is_gone(installer_id)

        deadline = time.monotonic() + 5

        while not process_is_gone(grandchild_id) and time.monotonic() < deadline:
            time.sleep(0.05)

        assert process_is_gone(grandchild_id)
        assert list(logs1.glob("sbx-init-gsd-*.log")) == []
        assert not layout1["marker"].exists()

        with open(layout1["lock"], "a+") as lock_handle:
            fcntl.flock(lock_handle, fcntl.LOCK_EX | fcntl.LOCK_NB)
    finally:
        if launcher.poll() is None:
            launcher.kill()
            launcher.communicate()

        if installer_id:
            kill_group_quietly(installer_id)
