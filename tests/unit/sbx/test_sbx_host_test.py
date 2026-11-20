# ------------------------------------------------------------------------------
# Tests of the host run: the Compose check, the pytest arguments, the live log
# ------------------------------------------------------------------------------
# main runs against a small repo made in tmp_path, whose three suites hold one
# test each, so the real pytest child, the log and the exit code are proven
# without Docker. The names of the run directories and the test sandboxes are
# tested here too.
# ------------------------------------------------------------------------------

import io
import os
import sys
from pathlib import Path

import pytest

from sbx import host_test
from sbx.docker import DockerResult
from sbx.hosttest_names import (
    ROOT_CA_DIR_NAME,
    RUN_DIR_PREFIX,
    is_run_dir_mount,
    shared_sandbox_name,
    temp_base_dir,
)
from sbx_helpers import DockerRecorder

COMPOSE_MESSAGE = "Docker Compose v2 or newer is required; install Docker Desktop"


# ------------------------------------------------------------------------------
# Helpers
# ------------------------------------------------------------------------------

def make_repo(repo: Path, sbx_body: str, integration_body: str, guard_body: str) -> None:
    for dir_name, file_name, body in [
        ("tests/unit/sbx", "test_probe_sbx.py", sbx_body),
        ("tests/integration", "test_probe_integration.py", integration_body),
        ("tests/guard", "test_probe_guard.py", guard_body),
    ]:
        suite_dir = repo / dir_name
        suite_dir.mkdir(parents=True)
        (suite_dir / file_name).write_text(body)

    (repo / "tests" / "integration" / "conftest.py").write_text(
        "def pytest_addoption(parser):\n"
        "    parser.addoption('--keep', action='store_true', default=False)\n"
    )


def compose_recorder(version_text: str) -> DockerRecorder:
    recorder = DockerRecorder()
    recorder.answer(["compose", "version", "--short"], DockerResult(0, version_text + "\n"))
    recorder.answer(["compose", "version"], DockerResult(0, "Docker Compose version v" + version_text))
    recorder.answer(["--version"], DockerResult(0, "Docker version 27.0.0"))

    return recorder


# ------------------------------------------------------------------------------
# The Compose version
# ------------------------------------------------------------------------------

@pytest.mark.parametrize("version_text", ["2.40.0-desktop.1", "v2.29.1", "5.0.1", "10.1"])
def test_compose_v2_and_later_pass(version_text):
    assert host_test.compose_version_ok(version_text)


@pytest.mark.parametrize("version_text", ["1.29.2", "", "abc", "v1.0"])
def test_compose_v1_empty_and_non_version_text_fail(version_text):
    assert not host_test.compose_version_ok(version_text)


# ------------------------------------------------------------------------------
# The pytest arguments
# ------------------------------------------------------------------------------

def test_the_pytest_arguments_run_the_three_suites_in_order_with_verbose_output():
    assert host_test.pytest_argument_list(False) == [
        "-m", "pytest", "-v", "-s", "-p", "no:cacheprovider",
        "tests/unit/sbx", "tests/integration", "tests/guard",
    ]


def test_keep_is_appended_and_no_option_stops_at_the_first_failure():
    argument_list = host_test.pytest_argument_list(True)

    assert argument_list[-1] == "--keep"

    for argument in argument_list:
        assert argument not in ("-x", "--exitfirst")
        assert not argument.startswith("--maxfail")


# ------------------------------------------------------------------------------
# Refusals
# ------------------------------------------------------------------------------

@pytest.mark.parametrize("argument_list", [["--bogus"], ["--keep", "--keep"], ["one", "two"]])
def test_main_refuses_an_argument_other_than_keep_with_a_usage_line(argument_list, tmp_path, capsys):
    recorder = DockerRecorder()

    code = host_test.main(argument_list, {}, docker=recorder, repo_dir=tmp_path)

    assert code == 2
    assert capsys.readouterr().err == "Usage: host-test.sh [--keep]\n"
    assert recorder.call_list == []
    assert not (tmp_path / "host-test.log").exists()


def test_main_stops_at_compose_v1_and_starts_no_child(tmp_path, capsys):
    recorder = compose_recorder("1.29.2")

    code = host_test.main([], {}, docker=recorder, repo_dir=tmp_path)

    assert code == 1
    assert capsys.readouterr().out == COMPOSE_MESSAGE + "\n"
    assert (tmp_path / "host-test.log").read_text() == COMPOSE_MESSAGE + "\n"
    assert recorder.call_list == [["compose", "version", "--short"]]


def test_main_stops_when_docker_does_not_answer(tmp_path, capsys):
    recorder = DockerRecorder()
    recorder.answer(["compose"], DockerResult(127, ""))

    code = host_test.main([], {}, docker=recorder, repo_dir=tmp_path)

    assert code == 1
    assert COMPOSE_MESSAGE in capsys.readouterr().out


# ------------------------------------------------------------------------------
# The live log
# ------------------------------------------------------------------------------

def test_run_and_log_returns_the_child_code_and_logs_every_line_in_order(capsys):
    log_handle = io.StringIO()

    code = host_test.run_and_log(
        [sys.executable, "-c", "print('one'); print('two'); raise SystemExit(3)"],
        dict(os.environ),
        log_handle,
    )

    assert code == 3
    assert log_handle.getvalue() == "one\ntwo\n"
    assert capsys.readouterr().out == "one\ntwo\n"


def test_run_and_log_merges_the_error_stream_of_the_child():
    log_handle = io.StringIO()

    code = host_test.run_and_log(
        [sys.executable, "-c", "import sys; print('out', flush=True); print('err', file=sys.stderr)"],
        dict(os.environ),
        log_handle,
    )

    assert code == 0
    assert sorted(log_handle.getvalue().splitlines()) == ["err", "out"]


def test_run_and_log_leaves_the_real_terminal_empty(capfd):
    log_handle = io.StringIO()

    host_test.run_and_log(
        [sys.executable, "-c", "import sys; print('out', flush=True); print('err', file=sys.stderr)"],
        dict(os.environ),
        log_handle,
    )

    captured = capfd.readouterr()

    assert captured.out == ""
    assert captured.err == ""


# ------------------------------------------------------------------------------
# The whole run on a small repo
# ------------------------------------------------------------------------------

def test_main_runs_the_suites_in_order_with_the_test_tag_and_keep_and_ends_with_the_pass_line(tmp_path, capsys):
    make_repo(
        tmp_path,
        "import os\n\ndef test_sbx_suite():\n    assert os.environ['SBX_IMAGE_TAG'] == 'test'\n",
        "def test_integration_suite(request):\n    assert request.config.getoption('--keep') is True\n",
        "def test_guard_suite():\n    pass\n",
    )
    environ = dict(os.environ)
    environ["SBX_IMAGE_TAG"] = "other"

    code = host_test.main(["--keep"], environ, docker=compose_recorder("2.40.0"), repo_dir=tmp_path)

    log_text = (tmp_path / "host-test.log").read_text()
    out_text = capsys.readouterr().out

    assert code == 0
    assert log_text == out_text
    assert "images: sbx-base:test, sbx-claude:test, sbx-cursor:test" in log_text
    assert "Docker version 27.0.0" in log_text
    assert log_text.index("test_sbx_suite") < log_text.index("test_integration_suite") < log_text.index("test_guard_suite")
    assert log_text.rstrip("\n").endswith(f"host-test.sh: every test passed; log: {tmp_path / 'host-test.log'}")


def test_main_runs_every_suite_after_a_failure_and_returns_the_pytest_code(tmp_path, capsys):
    make_repo(
        tmp_path,
        "def test_sbx_suite():\n    assert False\n",
        "def test_integration_suite():\n    assert False\n",
        "def test_guard_suite():\n    pass\n",
    )

    code = host_test.main([], dict(os.environ), docker=compose_recorder("2.40.0"), repo_dir=tmp_path)

    log_text = (tmp_path / "host-test.log").read_text()

    assert code == 1
    assert "test_sbx_suite FAILED" in log_text
    assert "test_integration_suite FAILED" in log_text
    assert "test_guard_suite PASSED" in log_text
    assert log_text.rstrip("\n").endswith(
        f"host-test.sh: pytest exited 1; the failures are listed above; log: {tmp_path / 'host-test.log'}"
    )


def test_main_leaves_the_real_terminal_empty_when_the_child_fails(tmp_path, capfd):
    make_repo(
        tmp_path,
        "def test_sbx_suite():\n    assert False\n",
        "def test_integration_suite():\n    pass\n",
        "def test_guard_suite():\n    pass\n",
    )

    host_test.main([], dict(os.environ), docker=compose_recorder("2.40.0"), repo_dir=tmp_path)

    captured = capfd.readouterr()

    assert captured.out == ""
    assert captured.err == ""


# ------------------------------------------------------------------------------
# The names of the host run
# ------------------------------------------------------------------------------

def test_the_temp_base_is_tmpdir_without_its_trailing_slash_else_tmp():
    assert temp_base_dir({"TMPDIR": "/var/folders/ab/T/"}) == Path("/var/folders/ab/T")
    assert temp_base_dir({"TMPDIR": "/"}) == Path("/tmp")
    assert temp_base_dir({"TMPDIR": ""}) == Path("/tmp")
    assert temp_base_dir({}) == Path("/tmp")


def test_the_shared_sandbox_name_is_hosttest_and_the_agent():
    assert shared_sandbox_name("claude") == "hosttest-claude"
    assert shared_sandbox_name("cursor") == "hosttest-cursor"


def test_the_test_root_certificate_directory_is_outside_the_run_directory_prefix():
    assert not ROOT_CA_DIR_NAME.startswith(RUN_DIR_PREFIX)


def test_a_workspace_mount_under_the_temp_base_with_the_run_prefix_is_a_run_directory(tmp_path):
    source = f"{tmp_path}/{RUN_DIR_PREFIX}20261120-010101.abc123/claude sandbox"

    assert is_run_dir_mount(source, tmp_path)


def test_a_docker_desktop_private_prefix_still_matches():
    assert is_run_dir_mount(
        f"/private/var/folders/ab/T/{RUN_DIR_PREFIX}20261120-010101.abc123/x",
        Path("/var/folders/ab/T"),
    )


@pytest.mark.parametrize(
    "source",
    ["/Users/you/sbx-hosttest", "/Users/you/projects/hosttest-claude", "/var/folders/ab/T/other/x", ""],
)
def test_a_user_directory_is_not_a_run_directory(source):
    assert not is_run_dir_mount(source, Path("/var/folders/ab/T"))
