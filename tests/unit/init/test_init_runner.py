# --------------------------------------------------------------------------------
# Tests of the sbx-init runner
# --------------------------------------------------------------------------------
# The lock, the marker, the order of the steps, the stop at the first FAIL, the
# load failures and the rerun. Every case runs on real files in a temp directory;
# the lock holder is a real second process.
# --------------------------------------------------------------------------------

import errno
import fcntl
import subprocess
import sys

import pytest

import init_runner
from hints import rebuild_hint
from init_helpers import run_lines, write_step_file

HOLDER_TEXT = """import fcntl, sys, time
handle = open(sys.argv[1], "a+")
fcntl.flock(handle, fcntl.LOCK_EX)
print("held", flush=True)
time.sleep(60)
"""
REBUILD_FIX_LINE = "      fix: " + rebuild_hint()
BUG_FIX_PREFIX = "      fix: this is a bug in sbx-init or a broken image; "


# --------------------------------------------------------------------------------
# Fixtures
# --------------------------------------------------------------------------------

@pytest.fixture
def shared1(tmp_path):
    shared_dir = tmp_path / "shared1"
    shared_dir.mkdir()

    return shared_dir


@pytest.fixture
def agents1(tmp_path):
    agents_dir = tmp_path / "agents1"
    (agents_dir / "group1").mkdir(parents=True)

    return agents_dir


@pytest.fixture
def marker1(tmp_path):
    return tmp_path / "marker1"


@pytest.fixture
def lock1(tmp_path):
    return tmp_path / "lock1"


# --------------------------------------------------------------------------------
# Order and the closing line
# --------------------------------------------------------------------------------

def test_passing_steps_print_ok_lines_in_file_name_order_and_write_the_marker(shared1, agents1, marker1, lock1):
    write_step_file(shared1, "020_step2", "step2")
    write_step_file(shared1, "010_step1", "step1")
    write_step_file(agents1 / "group1", "030_step3", "step3")

    status, line_list = run_lines(shared1, agents1, marker1, lock1)

    assert status == 0
    assert line_list == [
        "OK: step1: detail_step1",
        "OK: step2: detail_step2",
        "OK: step3: detail_step3",
        "sbx-init: 3 steps passed; run sbx-selfcheck to check the sandbox",
    ]
    assert marker1.is_file()


def test_a_shared_step_numbered_800_runs_after_an_agent_step_numbered_050(shared1, agents1, marker1, lock1):
    write_step_file(shared1, "800_step1", "step1")
    write_step_file(agents1 / "group1", "050_step2", "step2")

    status, line_list = run_lines(shared1, agents1, marker1, lock1)

    assert status == 0
    assert line_list[:2] == ["OK: step2: detail_step2", "OK: step1: detail_step1"]


def test_a_shared_and_an_agent_file_with_the_same_name_run_shared_first(shared1, agents1, marker1, lock1):
    write_step_file(agents1 / "group1", "050_same", "agent1")
    write_step_file(shared1, "050_same", "shared1")

    status, line_list = run_lines(shared1, agents1, marker1, lock1)

    assert status == 0
    assert line_list[:2] == ["OK: shared1: detail_shared1", "OK: agent1: detail_agent1"]


def test_a_step_file_with_an_empty_step_list_adds_no_line(shared1, agents1, marker1, lock1):
    (shared1 / "010_empty.py").write_text("STEP_LIST = []\n")
    write_step_file(agents1 / "group1", "020_step1", "step1")

    status, line_list = run_lines(shared1, agents1, marker1, lock1)

    assert status == 0
    assert line_list == [
        "OK: step1: detail_step1",
        "sbx-init: 1 steps passed; run sbx-selfcheck to check the sandbox",
    ]


# --------------------------------------------------------------------------------
# Stop at the first FAIL and the marker
# --------------------------------------------------------------------------------

def test_a_failing_step_stops_the_run_and_leaves_no_marker(shared1, agents1, marker1, lock1, tmp_path):
    side_effect1 = tmp_path / "side_effect1"
    side_effect3 = tmp_path / "side_effect3"
    write_step_file(shared1, "010_step1", "step1", touch_file=side_effect1)
    write_step_file(shared1, "020_step2", "step2", passes=False)
    write_step_file(agents1 / "group1", "030_step3", "step3", touch_file=side_effect3)

    status, line_list = run_lines(shared1, agents1, marker1, lock1)

    assert status == 1
    assert line_list == [
        "OK: step1: detail_step1",
        "FAIL: step2: detail_step2",
        "      fix: hint_step2",
        "sbx-init: stopped at step2",
    ]
    assert side_effect1.exists()
    assert not side_effect3.exists()
    assert not marker1.exists()


def test_a_marker_from_an_earlier_run_is_removed_when_the_run_fails(shared1, agents1, marker1, lock1):
    marker1.touch()
    write_step_file(shared1, "010_step1", "step1", passes=False)
    write_step_file(agents1 / "group1", "020_step2", "step2")

    status, _ = run_lines(shared1, agents1, marker1, lock1)

    assert status == 1
    assert not marker1.exists()


def test_a_step_that_raises_becomes_a_fail_with_the_bug_fix(shared1, agents1, marker1, lock1):
    (shared1 / "010_raises.py").write_text(
        "from check_result import Check\n\n\ndef step1():\n    raise RuntimeError('detail1')\n\n\n"
        "STEP_LIST = [Check('raises1', step1)]\n"
    )
    write_step_file(agents1 / "group1", "020_step2", "step2")

    status, line_list = run_lines(shared1, agents1, marker1, lock1)

    assert status == 1
    assert line_list[0] == "FAIL: raises1: raised RuntimeError: detail1"
    assert line_list[1].startswith(BUG_FIX_PREFIX)
    assert line_list[2] == "sbx-init: stopped at raises1"


def test_a_step_that_returns_a_string_becomes_a_fail_with_the_bug_fix(shared1, agents1, marker1, lock1):
    (shared1 / "010_string.py").write_text(
        "from check_result import Check\n\n\ndef step1():\n    return 'text1'\n\n\n"
        "STEP_LIST = [Check('string1', step1)]\n"
    )
    write_step_file(agents1 / "group1", "020_step2", "step2")

    status, line_list = run_lines(shared1, agents1, marker1, lock1)

    assert status == 1
    assert line_list[0] == "FAIL: string1: returned str instead of a CheckResult"
    assert line_list[1].startswith(BUG_FIX_PREFIX)
    assert not marker1.exists()


# --------------------------------------------------------------------------------
# Load failures
# --------------------------------------------------------------------------------

def test_a_step_file_that_raises_at_import_is_one_load_failure_and_stops_the_run(shared1, agents1, marker1, lock1):
    bad_file = agents1 / "group1" / "020_bad.py"
    bad_file.write_text("raise RuntimeError('detail1')\n")
    write_step_file(shared1, "010_step1", "step1")
    write_step_file(agents1 / "group1", "030_step3", "step3")

    status, line_list = run_lines(shared1, agents1, marker1, lock1)

    assert status == 1
    assert line_list == [
        "OK: step1: detail_step1",
        f"FAIL: load-group1-020-bad: {bad_file} did not load: RuntimeError: detail1",
        REBUILD_FIX_LINE,
        "sbx-init: stopped at load-group1-020-bad",
    ]
    assert not marker1.exists()


def test_a_step_file_without_a_step_list_is_one_load_failure(shared1, agents1, marker1, lock1):
    bad_file = shared1 / "010_bad.py"
    bad_file.write_text("VALUE1 = 1\n")
    write_step_file(agents1 / "group1", "020_step2", "step2")

    status, line_list = run_lines(shared1, agents1, marker1, lock1)

    assert status == 1
    assert line_list == [
        f"FAIL: load-shared1-010-bad: {bad_file} defines no STEP_LIST",
        REBUILD_FIX_LINE,
        "sbx-init: stopped at load-shared1-010-bad",
    ]


def test_a_step_list_that_is_not_a_list_of_steps_is_one_load_failure(shared1, agents1, marker1, lock1):
    bad_file = shared1 / "010_bad.py"
    bad_file.write_text("STEP_LIST = ['text1']\n")
    write_step_file(agents1 / "group1", "020_step2", "step2")

    status, line_list = run_lines(shared1, agents1, marker1, lock1)

    assert status == 1
    assert line_list == [
        f"FAIL: load-shared1-010-bad: {bad_file} defines a STEP_LIST that is not a list of steps",
        REBUILD_FIX_LINE,
        "sbx-init: stopped at load-shared1-010-bad",
    ]


def test_a_missing_agent_dir_prints_only_the_agent_steps_failure(shared1, tmp_path, marker1, lock1):
    side_effect1 = tmp_path / "side_effect1"
    write_step_file(shared1, "010_step1", "step1", touch_file=side_effect1)
    missing_dir = tmp_path / "missing1"

    status, line_list = run_lines(shared1, missing_dir, marker1, lock1)

    assert status == 1
    assert line_list == [
        f"FAIL: load-agent-steps: found no agent steps in {missing_dir}, so the image's own steps did not run",
        REBUILD_FIX_LINE,
        "sbx-init: stopped at load-agent-steps",
    ]
    assert not side_effect1.exists()
    assert not marker1.exists()


def test_an_empty_agent_dir_prints_only_the_agent_steps_failure(shared1, tmp_path, marker1, lock1):
    write_step_file(shared1, "010_step1", "step1")
    empty_dir = tmp_path / "empty1"
    empty_dir.mkdir()

    status, line_list = run_lines(shared1, empty_dir, marker1, lock1)

    assert status == 1
    assert line_list[0].startswith("FAIL: load-agent-steps: ")
    assert len(line_list) == 3


def test_an_agent_dir_with_only_empty_subdirs_prints_only_the_agent_steps_failure(
    shared1, agents1, marker1, lock1
):
    write_step_file(shared1, "010_step1", "step1")

    status, line_list = run_lines(shared1, agents1, marker1, lock1)

    assert status == 1
    assert line_list[0].startswith("FAIL: load-agent-steps: ")
    assert line_list[2] == "sbx-init: stopped at load-agent-steps"
    assert not marker1.exists()


# --------------------------------------------------------------------------------
# Rerun
# --------------------------------------------------------------------------------

def test_two_runs_in_a_row_print_the_same_lines_and_both_exit_zero(shared1, agents1, marker1, lock1):
    write_step_file(shared1, "010_step1", "step1")
    write_step_file(agents1 / "group1", "020_step2", "step2")

    first_status, first_line_list = run_lines(shared1, agents1, marker1, lock1)
    second_status, second_line_list = run_lines(shared1, agents1, marker1, lock1)

    assert first_status == 0
    assert second_status == 0
    assert second_line_list == first_line_list
    assert marker1.is_file()


def test_a_rerun_runs_every_step_again(shared1, agents1, marker1, lock1, tmp_path):
    side_effect1 = tmp_path / "side_effect1"
    write_step_file(shared1, "010_step1", "step1", touch_file=side_effect1)
    write_step_file(agents1 / "group1", "020_step2", "step2")
    run_lines(shared1, agents1, marker1, lock1)
    side_effect1.unlink()

    status, _ = run_lines(shared1, agents1, marker1, lock1)

    assert status == 0
    assert side_effect1.exists()


# --------------------------------------------------------------------------------
# Lock
# --------------------------------------------------------------------------------

def test_a_run_started_while_another_process_holds_the_lock_changes_nothing(
    shared1, agents1, marker1, lock1, tmp_path
):
    side_effect1 = tmp_path / "side_effect1"
    write_step_file(shared1, "010_step1", "step1", touch_file=side_effect1)
    write_step_file(agents1 / "group1", "020_step2", "step2")
    marker1.touch()
    holder = subprocess.Popen([sys.executable, "-c", HOLDER_TEXT, str(lock1)], stdout=subprocess.PIPE, text=True)

    try:
        assert holder.stdout.readline().strip() == "held"

        blocked_status, blocked_line_list = run_lines(shared1, agents1, marker1, lock1)
        marker_kept = marker1.exists()
        side_effect_made = side_effect1.exists()
    finally:
        holder.kill()
        holder.wait()
        holder.stdout.close()

    assert blocked_status == 1
    assert blocked_line_list == [
        "FAIL: lock: another sbx-init is running",
        "      fix: wait for it to finish, then run sbx-init again",
        "sbx-init: stopped at lock",
    ]
    assert marker_kept
    assert not side_effect_made

    status, _ = run_lines(shared1, agents1, marker1, lock1)

    assert status == 0


def test_the_lock_is_free_again_after_a_run_in_the_same_process(shared1, agents1, marker1, lock1):
    write_step_file(shared1, "010_step1", "step1")
    write_step_file(agents1 / "group1", "020_step2", "step2")
    run_lines(shared1, agents1, marker1, lock1)

    with open(lock1, "a+") as handle:
        fcntl.flock(handle, fcntl.LOCK_EX | fcntl.LOCK_NB)


def test_a_lock_file_that_cannot_be_opened_is_a_lock_failure(shared1, agents1, marker1, tmp_path):
    write_step_file(agents1 / "group1", "020_step2", "step2")
    lock_in_missing_dir = tmp_path / "missing1" / "lock1"

    status, line_list = run_lines(shared1, agents1, marker1, lock_in_missing_dir)

    assert status == 1
    assert line_list[0].startswith(f"FAIL: lock: cannot open {lock_in_missing_dir}: ")
    assert line_list[1] == f"      fix: check that {lock_in_missing_dir.parent} is writable; " + rebuild_hint()
    assert line_list[2] == "sbx-init: stopped at lock"


def test_a_lock_call_that_fails_with_another_error_closes_the_handle_and_raises(tmp_path):
    handle_list = []

    def failing_flock(handle, operation):
        handle_list.append(handle)

        raise OSError(errno.EIO, "input/output error")

    with pytest.raises(OSError):
        init_runner._take_lock(tmp_path / "lock1", failing_flock)

    assert handle_list[0].closed


def test_a_lock_call_that_would_block_closes_the_handle_and_returns_none(tmp_path):
    handle_list = []

    def blocking_flock(handle, operation):
        handle_list.append(handle)

        raise BlockingIOError(errno.EAGAIN, "resource temporarily unavailable")

    assert init_runner._take_lock(tmp_path / "lock1", blocking_flock) is None
    assert handle_list[0].closed


# --------------------------------------------------------------------------------
# Main
# --------------------------------------------------------------------------------

def test_main_with_an_argument_returns_two_with_one_usage_line_on_stderr(capsys):
    status = init_runner.main(["x"])

    captured = capsys.readouterr()
    assert status == 2
    assert captured.out == ""
    assert captured.err == "Usage: sbx-init (no arguments)\n"
