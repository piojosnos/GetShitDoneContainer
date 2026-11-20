# ------------------------------------------------------------------------------
# Tests of the helpers the integration scenarios share
# ------------------------------------------------------------------------------
# The step note, the timeout that stops a whole process group, the live runner,
# the selfcheck reader and the throwaway root certificate. None of the cases
# needs Docker.
# ------------------------------------------------------------------------------

import io
import subprocess
import sys
import time
from pathlib import Path

import pytest

from scenario_helpers import (
    certificate_fingerprint,
    certificate_is_valid,
    container_map_from_text,
    make_root_certificate,
    run_sbx,
    run_streamed,
    run_timeout,
    selfcheck_problem_list,
    step,
)


# ------------------------------------------------------------------------------
# Helpers
# ------------------------------------------------------------------------------

def process_is_alive(pid: int) -> bool:
    completed = subprocess.run(
        ["ps", "-o", "stat=", "-p", str(pid)],
        capture_output=True,
        text=True,
        check=False,
    )
    state = completed.stdout.strip()

    return completed.returncode == 0 and state != "" and not state.startswith("Z")


def wait_until_gone(pid: int, seconds: float) -> bool:
    deadline = time.monotonic() + seconds

    while time.monotonic() < deadline:
        if not process_is_alive(pid):
            return True

        time.sleep(0.1)

    return not process_is_alive(pid)


# ------------------------------------------------------------------------------
# step
# ------------------------------------------------------------------------------

def test_a_failing_step_adds_the_step_name_as_a_note_and_reraises():
    with pytest.raises(AssertionError) as raised:
        with step("upgrade"):
            assert 1 == 2

    assert raised.value.__notes__ == ["STEP FAILED: upgrade"]


def test_a_passing_step_adds_nothing():
    with step("upgrade"):
        value = 1 + 1

    assert value == 2


# ------------------------------------------------------------------------------
# run_timeout
# ------------------------------------------------------------------------------

def test_run_timeout_returns_the_code_and_both_streams():
    result = run_timeout(
        [sys.executable, "-c", "import sys; print('out'); print('err', file=sys.stderr); sys.exit(4)"],
        30,
    )

    assert result.returncode == 4
    assert result.stdout == "out\n"
    assert result.stderr == "err\n"
    assert result.timed_out is False


def test_run_timeout_hands_the_stdin_text_to_the_command():
    result = run_timeout([sys.executable, "-c", "import sys; print(sys.stdin.read().upper())"], 30, stdin="abc")

    assert result.stdout == "ABC\n"


def test_run_timeout_closes_stdin_when_none_is_given():
    result = run_timeout([sys.executable, "-c", "import sys; print(repr(sys.stdin.read()))"], 30)

    assert result.stdout == "''\n"


def test_run_timeout_stops_the_whole_group_so_no_grandchild_keeps_running():
    started = time.monotonic()

    result = run_timeout(["sh", "-c", "sleep 30 & echo $!; wait"], 1)

    elapsed = time.monotonic() - started
    sleep_pid = int(result.stdout.split()[0])

    assert result.timed_out is True
    assert elapsed < 10
    assert wait_until_gone(sleep_pid, 5)


def test_run_timeout_reports_a_command_that_cannot_start_as_exit_127(tmp_path):
    result = run_timeout([str(tmp_path / "no-such-command")], 30)

    assert result.returncode == 127
    assert result.timed_out is False
    assert "no-such-command" in result.stderr


def test_run_sbx_finds_the_command_on_the_path_of_the_environment_it_is_given(tmp_path):
    bin_dir = tmp_path / "bin1"
    bin_dir.mkdir()
    command = bin_dir / "sbx-probe"
    command.write_text('#!/bin/sh\necho "probe $1 $SBX_PROBE"\n')
    command.chmod(0o755)

    result = run_sbx("sbx-probe", ["arg1"], {"PATH": f"{bin_dir}:/usr/bin:/bin", "SBX_PROBE": "env1"})

    assert result.returncode == 0
    assert result.stdout == "probe arg1 env1\n"


# ------------------------------------------------------------------------------
# run_streamed
# ------------------------------------------------------------------------------

def test_run_streamed_echoes_and_logs_every_line_merged_and_returns_the_code(tmp_path):
    log_file = tmp_path / "run.log"
    output = io.StringIO()

    result = run_streamed(
        [sys.executable, "-c", "import sys; print('one', flush=True); print('two', file=sys.stderr); sys.exit(2)"],
        30,
        None,
        output,
        log_file,
    )

    assert result.returncode == 2
    assert result.timed_out is False
    assert sorted(result.stdout.splitlines()) == ["one", "two"]
    assert sorted(log_file.read_text().splitlines()) == ["one", "two"]
    assert sorted(output.getvalue().splitlines()) == ["one", "two"]


def test_run_streamed_leaves_the_real_terminal_empty_and_fills_the_injected_stream(tmp_path, capfd):
    output = io.StringIO()

    run_streamed([sys.executable, "-c", "print('one')"], 30, None, output, tmp_path / "run.log")

    captured = capfd.readouterr()

    assert captured.out == ""
    assert captured.err == ""
    assert output.getvalue() == "one\n"


def test_run_streamed_stops_the_group_on_a_timeout(tmp_path):
    started = time.monotonic()

    result = run_streamed(["sh", "-c", "sleep 30 & echo $!; wait"], 1, None, io.StringIO(), tmp_path / "run.log")

    elapsed = time.monotonic() - started
    sleep_pid = int(result.stdout.split()[0])

    assert result.timed_out is True
    assert elapsed < 10
    assert wait_until_gone(sleep_pid, 5)


# ------------------------------------------------------------------------------
# The container listing
# ------------------------------------------------------------------------------

def test_the_container_map_holds_every_sbx_container_but_the_excluded_one():
    text = (
        "/sbx-one\tid1\t2026-11-20T01:00:00Z\n"
        "/sbx-two\tid2\t2026-11-20T02:00:00Z\n"
        "/other\tid3\t2026-11-20T03:00:00Z\n"
        "a line without tabs\n"
    )

    assert container_map_from_text(text, "sbx-two") == {"sbx-one": ("id1", "2026-11-20T01:00:00Z")}


# ------------------------------------------------------------------------------
# The selfcheck reader
# ------------------------------------------------------------------------------

def selfcheck_output(pass_count: int, extra_line_list: list[str]) -> str:
    line_list = []

    for number in range(pass_count):
        line_list.append(f"PASS: check-{number}: detail {number}")

    line_list += extra_line_list
    line_list.append(f"sbx-selfcheck: {pass_count} checks, 0 failed")

    return "\n".join(line_list) + "\n"


def test_a_clean_output_with_the_expected_count_has_no_problem():
    assert selfcheck_problem_list(selfcheck_output(3, []), 3) == []


def test_a_wrong_count_is_a_problem():
    assert selfcheck_problem_list(selfcheck_output(2, []), 3) == ["2 check lines, expected 3"]


def test_a_fail_line_is_listed_with_its_fix_line():
    output = selfcheck_output(2, ["FAIL: git-identity: no user.name", "      fix: git config --global user.name NAME"])

    problem_list = selfcheck_problem_list(output, 3)

    assert problem_list == ["FAIL: git-identity: no user.name\n      fix: git config --global user.name NAME"]


def test_a_fail_line_without_a_fix_line_is_still_listed():
    output = selfcheck_output(2, ["FAIL: git-identity: no user.name"])

    assert selfcheck_problem_list(output, 3) == ["FAIL: git-identity: no user.name"]


def test_a_line_that_is_none_of_the_known_kinds_is_a_problem():
    output = selfcheck_output(3, ["Traceback (most recent call last):"])

    assert selfcheck_problem_list(output, 3) == ["unexpected line: Traceback (most recent call last):"]


def test_a_pass_line_saying_no_root_certificate_was_requested_is_a_problem():
    output = "PASS: extra-ca-system-bundle: no extra root certificate requested\nsbx-selfcheck: 1 checks, 0 failed\n"

    problem_list = selfcheck_problem_list(output, 1)

    assert len(problem_list) == 1
    assert problem_list[0].startswith("the test image should carry a root certificate")


# ------------------------------------------------------------------------------
# The throwaway root certificate (real openssl)
# ------------------------------------------------------------------------------

def test_the_root_certificate_is_made_valid_with_a_fingerprint_and_its_key_is_gone(tmp_path):
    cert_file = tmp_path / "ca dir" / "root-ca.pem"

    assert not certificate_is_valid(cert_file)

    make_root_certificate(cert_file)

    assert certificate_is_valid(cert_file)
    assert (cert_file.parent.stat().st_mode & 0o777) == 0o700
    assert list(cert_file.parent.iterdir()) == [cert_file]
    assert len(certificate_fingerprint(cert_file)) == 64


def test_the_fingerprint_of_a_missing_file_is_empty(tmp_path):
    assert certificate_fingerprint(tmp_path / "missing.pem") == ""


def test_a_file_that_is_not_a_certificate_is_not_valid(tmp_path):
    bad_file = Path(tmp_path) / "bad.pem"
    bad_file.write_text("not a certificate\n")

    assert not certificate_is_valid(bad_file)
