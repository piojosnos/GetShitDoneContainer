# ------------------------------------------------------------------------------
# Tests of the helpers the integration scenarios share
# ------------------------------------------------------------------------------
# The step note, the timeout that stops a whole process group, the live runner,
# the failure text, the container questions, the throwaway sandboxes, the selfcheck
# reader and the throwaway root certificate. None of the cases needs Docker.
# ------------------------------------------------------------------------------

import io
import json
import os
import subprocess
import sys
import time
from pathlib import Path

import pytest

from agent_specs import CLAUDE_SPEC, CURSOR_SPEC
from scenario_helpers import (
    REPO_DIR,
    CommandResult,
    certificate_fingerprint,
    certificate_is_valid,
    container_id_of,
    container_is_running,
    container_map_from_text,
    describe_result,
    make_root_certificate,
    register_sandbox,
    run_sbx,
    run_streamed,
    run_timeout,
    selfcheck_problem_list,
    step,
    throwaway_sandbox,
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
# describe_result and the container questions
# ------------------------------------------------------------------------------

def test_a_result_is_described_with_its_code_and_both_streams():
    result = CommandResult(3, "out1\n", "err1\n", False)

    assert describe_result(result) == "exit 3\nstdout: out1\nstderr: err1"


def test_a_timed_out_result_says_so():
    result = CommandResult(-9, "", "", True)

    assert describe_result(result).startswith("exit -9 (timed out)")


def test_a_container_docker_does_not_know_is_not_running_and_has_no_id():
    assert not container_is_running("sbx-no-such-container-1")
    assert container_id_of("sbx-no-such-container-1") == ""


# ------------------------------------------------------------------------------
# Throwaway sandboxes
# ------------------------------------------------------------------------------

def command_environ(config_dir: Path) -> dict[str, str]:
    environ = {}

    for key, value in os.environ.items():
        if key.startswith("SBX_") or key.startswith("COMPOSE_"):
            continue

        environ[key] = value

    environ["PATH"] = f"{REPO_DIR / 'bin'}{os.pathsep}{os.environ.get('PATH', '')}"
    environ["SBX_CONFIG_DIR"] = str(config_dir)
    environ["SBX_IMAGE_TAG"] = "test"

    return environ


def test_a_throwaway_sandbox_is_named_by_story_and_agent_and_its_directory_has_a_space(tmp_path):
    sandbox1 = throwaway_sandbox("life", CLAUDE_SPEC, tmp_path)
    sandbox2 = throwaway_sandbox("life", CURSOR_SPEC, tmp_path)

    assert sandbox1.name == "hosttest-life-claude"
    assert sandbox1.container == "sbx-hosttest-life-claude"
    assert sandbox1.sandbox_dir == tmp_path / "life claude"
    assert sandbox1.project_dir == tmp_path / "life claude" / "hosttest-life-claude"
    assert sandbox1.state_dir == tmp_path / "life claude" / "state"
    assert sandbox1.entry_file == tmp_path / "cfg" / "sandboxes" / "hosttest-life-claude.json"
    assert sandbox2.name == "hosttest-life-cursor"
    assert sandbox2.sandbox_dir != sandbox1.sandbox_dir


def test_register_sandbox_runs_the_real_sbx_add_and_puts_the_name_on_the_cleanup_list_once(tmp_path):
    config1 = tmp_path / "cfg"
    environ1 = command_environ(config1)
    sandbox1 = throwaway_sandbox("life", CURSOR_SPEC, tmp_path)
    cleanup_list = []

    first = register_sandbox(sandbox1, environ1, cleanup_list)

    assert first.returncode == 0, describe_result(first)
    assert json.loads(sandbox1.entry_file.read_text()) == {"path": str(sandbox1.sandbox_dir), "agent": "cursor"}
    assert sandbox1.project_dir.is_dir()
    assert sandbox1.state_dir.is_dir()
    assert cleanup_list == ["hosttest-life-cursor"]


def test_register_sandbox_adds_nothing_to_the_cleanup_list_when_sbx_add_refuses(tmp_path):
    environ1 = command_environ(tmp_path / "cfg")
    sandbox1 = throwaway_sandbox("life", CLAUDE_SPEC, tmp_path)
    cleanup_list = []

    register_sandbox(sandbox1, environ1, cleanup_list)
    cleanup_list.clear()

    second = register_sandbox(sandbox1, environ1, cleanup_list)

    assert second.returncode == 1
    assert "is already registered" in second.stderr
    assert cleanup_list == []


def test_register_sandbox_keeps_one_cleanup_entry_when_the_sandbox_is_added_again(tmp_path):
    environ1 = command_environ(tmp_path / "cfg")
    sandbox1 = throwaway_sandbox("life", CLAUDE_SPEC, tmp_path)
    cleanup_list = []

    register_sandbox(sandbox1, environ1, cleanup_list)
    sandbox1.entry_file.unlink()
    again = register_sandbox(sandbox1, environ1, cleanup_list)

    assert again.returncode == 0, describe_result(again)
    assert cleanup_list == ["hosttest-life-claude"]


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
