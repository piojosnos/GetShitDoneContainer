# ------------------------------------------------------------------------------
# Tests of sbx-rm
# ------------------------------------------------------------------------------
# Real registry files under tmp_path. Docker is the recorder; the terminal check
# and the answer reader are stand-ins passed as parameters, so a question on a
# terminal is tested without one.
# ------------------------------------------------------------------------------

import os

import pytest

from sbx import rm as rm_module
from sbx.docker import DockerResult
from sbx_helpers import REPO_DIR, environ_for, write_json_entry

RUNNING_PREFIX = ["container", "inspect", "--format", "{{.State.Running}}"]
USAGE_TEXT = "Usage: sbx-rm NAME [--unregister] [--yes]\n"
WARNING_TEXT = "sbx-rm: sbx-sbx1 is running; removing it will close its open shells and Claude sessions\n"
NO_TERMINAL_TEXT = (
    "sbx-rm: sbx-sbx1 is running and there is no terminal to confirm on; "
    "add --yes to remove it anyway. Nothing was changed\n"
)
NOT_REMOVED_TEXT = "sbx-rm: sbx-sbx1 was not removed; it still runs and nothing was changed\n"
PROMPT_TEXT = "Remove the running sbx-sbx1? [y/N] "


# ------------------------------------------------------------------------------
# Fixtures and stand-ins
# ------------------------------------------------------------------------------

class Console:
    # Stands in for the terminal check and the answer reader. A call of
    # read_answer without a planned answer fails the test.
    def __init__(self, terminal: bool = False, answer_list: list[str] | None = None) -> None:
        self.terminal = terminal
        self.answer_list = list(answer_list or [])
        self.is_terminal_call_count = 0
        self.prompt_list: list[str] = []

    def is_terminal(self) -> bool:
        self.is_terminal_call_count += 1

        return self.terminal

    def read_answer(self, prompt: str) -> str:
        self.prompt_list.append(prompt)

        if not self.answer_list:
            raise EOFError

        return self.answer_list.pop(0)


@pytest.fixture
def entry_file(registry, tmp_path):
    project_dir = tmp_path / "one dir"
    write_json_entry(registry, "sbx1", str(project_dir), "cursor")

    return registry / "sbx1.json"


@pytest.fixture
def broken_entry_file(registry):
    return write_json_entry(registry, "sbx1", "relative/dir", "claude")


@pytest.fixture
def run_rm(config_dir, recorder, capsys):
    def run(argument_list, console=None, extra_map=None):
        console = console or Console()
        environ = environ_for(config_dir, extra_map)
        exit_code = rm_module.main(
            argument_list,
            environ,
            docker=recorder,
            repo_dir=REPO_DIR,
            is_terminal=console.is_terminal,
            read_answer=console.read_answer,
        )
        captured = capsys.readouterr()

        return exit_code, captured.out, captured.err

    return run


def _down_call_list(recorder):
    down_list = []

    for call in recorder.call_list:
        if call[0] == "compose" and call[-1] == "down":
            down_list.append(call)

    return down_list


def _set_running(recorder):
    recorder.answer(RUNNING_PREFIX, DockerResult(0, "true\n"))


# ------------------------------------------------------------------------------
# The arguments
# ------------------------------------------------------------------------------

@pytest.mark.parametrize(
    "argument_list",
    [
        [],
        ["a", "b"],
        ["a", "b", "c"],
        ["--unregister"],
        ["--yes"],
        ["--yes", "--unregister"],
        ["sbx1", "--force"],
        ["sbx1", "--yes", "--yes"],
        ["sbx1", "--unregister", "--unregister"],
        ["sbx1", "--yes", "--unregister", "x"],
    ],
)
def test_a_wrong_set_of_arguments_prints_the_usage_and_does_not_reach_docker(argument_list, run_rm, recorder):
    exit_code, out, err = run_rm(argument_list)

    assert exit_code == 2
    assert out == ""
    assert err == USAGE_TEXT
    assert recorder.call_list == []


@pytest.mark.parametrize(
    "argument_list",
    [
        ["sbx1", "--yes"],
        ["--yes", "sbx1"],
        ["--unregister", "sbx1", "--yes"],
        ["--yes", "--unregister", "sbx1"],
        ["sbx1", "--unregister", "--yes"],
    ],
)
def test_the_options_come_before_or_after_the_name_in_any_order(argument_list, run_rm, entry_file, recorder):
    exit_code, _, err = run_rm(argument_list)

    assert exit_code == 0, err
    assert len(_down_call_list(recorder)) == 1


# ------------------------------------------------------------------------------
# Refusals before Docker
# ------------------------------------------------------------------------------

def test_an_unregistered_name_is_refused(run_rm, recorder):
    exit_code, _, err = run_rm(["ghost"])

    assert exit_code == 1
    assert err == "sbx-rm: ghost is not registered; run: sbx-add ghost HOST_PATH\n"
    assert recorder.call_list == []


@pytest.mark.parametrize("argument_list", [["../x"], ["--unregister", "../x"], ["Demo"]])
def test_a_name_that_breaks_the_rule_is_refused(argument_list, run_rm, recorder):
    exit_code, _, err = run_rm(argument_list)

    assert exit_code == 1
    assert "breaks the sandbox name rule" in err
    assert recorder.call_list == []


def test_a_tag_other_than_local_or_test_is_refused_first(run_rm, entry_file, recorder):
    exit_code, _, err = run_rm(["sbx1"], extra_map={"SBX_IMAGE_TAG": "latest"})

    assert exit_code == 1
    assert err == "sbx-rm: SBX_IMAGE_TAG must be local or test, not 'latest'\n"
    assert recorder.call_list == []
    assert entry_file.is_file()


# ------------------------------------------------------------------------------
# A stopped sandbox
# ------------------------------------------------------------------------------

def test_a_stopped_sandbox_goes_with_down_and_the_closing_line(run_rm, entry_file, recorder, tmp_path):
    exit_code, out, err = run_rm(["sbx1"])

    assert exit_code == 0
    assert err == ""
    assert out == f"sbx-rm: the container sbx-sbx1 is gone; nothing in {tmp_path / 'one dir'} was changed\n"
    assert _down_call_list(recorder) == [
        ["compose", "--env-file", "/dev/null", "-p", "sbx-sbx1", "-f", f"{REPO_DIR}/compose.yml", "down"]
    ]
    assert entry_file.is_file()


def test_down_is_run_with_the_environment_of_the_entry(run_rm, entry_file, recorder, tmp_path):
    run_rm(["sbx1"], extra_map={"COMPOSE_PROJECT_NAME": "ambient"})

    compose_environ = recorder.environ_list[recorder.call_list.index(_down_call_list(recorder)[0])]

    assert compose_environ["SBX_DIR"] == str(tmp_path / "one dir")
    assert compose_environ["SBX_AGENT"] == "cursor"
    assert "COMPOSE_PROJECT_NAME" not in compose_environ


def test_a_failed_down_keeps_the_entry_and_says_so(run_rm, entry_file, recorder, tmp_path):
    recorder.answer(["compose"], DockerResult(1, ""))

    exit_code, out, err = run_rm(["sbx1", "--unregister"])

    assert exit_code == 1
    assert err == (
        "sbx-rm: docker compose down failed for sbx-sbx1; the registry entry stays "
        f"and nothing in {tmp_path / 'one dir'} was changed\n"
    )
    assert "is gone" not in out
    assert entry_file.is_file()


# ------------------------------------------------------------------------------
# A running sandbox
# ------------------------------------------------------------------------------

def test_a_running_sandbox_without_yes_and_without_a_terminal_is_refused(run_rm, entry_file, recorder):
    _set_running(recorder)
    console = Console(terminal=False)

    exit_code, out, err = run_rm(["sbx1"], console)

    assert exit_code == 1
    assert out == WARNING_TEXT
    assert err == NO_TERMINAL_TEXT
    assert "--yes" in err
    assert _down_call_list(recorder) == []
    assert console.prompt_list == []


@pytest.mark.parametrize("answer", ["y", "Y"])
def test_a_y_on_a_terminal_removes_the_running_sandbox(answer, run_rm, entry_file, recorder):
    _set_running(recorder)
    console = Console(terminal=True, answer_list=[answer])

    exit_code, out, _ = run_rm(["sbx1"], console)

    assert exit_code == 0
    assert out.startswith(WARNING_TEXT)
    assert console.prompt_list == [PROMPT_TEXT]
    assert len(_down_call_list(recorder)) == 1


@pytest.mark.parametrize("answer", ["n", "N", "", "yes", " y"])
def test_anything_but_y_on_a_terminal_keeps_the_running_sandbox(answer, run_rm, entry_file, recorder):
    _set_running(recorder)
    console = Console(terminal=True, answer_list=[answer])

    exit_code, _, err = run_rm(["sbx1"], console)

    assert exit_code == 1
    assert err == NOT_REMOVED_TEXT
    assert _down_call_list(recorder) == []


def test_a_closed_input_on_a_terminal_reads_as_no(run_rm, entry_file, recorder):
    _set_running(recorder)
    console = Console(terminal=True, answer_list=[])

    exit_code, _, err = run_rm(["sbx1"], console)

    assert exit_code == 1
    assert err == NOT_REMOVED_TEXT
    assert _down_call_list(recorder) == []


def test_yes_skips_the_question_and_prints_the_sessions_warning(run_rm, entry_file, recorder):
    _set_running(recorder)
    console = Console(terminal=True)

    exit_code, out, _ = run_rm(["sbx1", "--yes"], console)

    assert exit_code == 0
    assert out.startswith(WARNING_TEXT)
    assert console.prompt_list == []
    assert console.is_terminal_call_count == 0
    assert len(_down_call_list(recorder)) == 1


def test_a_stopped_sandbox_is_never_asked_about(run_rm, entry_file, recorder):
    console = Console(terminal=True)

    exit_code, out, _ = run_rm(["sbx1"], console)

    assert exit_code == 0
    assert "will close its open shells" not in out
    assert console.prompt_list == []


# ------------------------------------------------------------------------------
# --unregister
# ------------------------------------------------------------------------------

def test_unregister_deletes_the_entry_after_a_good_down(run_rm, entry_file, recorder, tmp_path):
    exit_code, out, _ = run_rm(["sbx1", "--unregister"])

    assert exit_code == 0
    assert not entry_file.exists()
    assert out.splitlines() == [
        f'sbx-rm: deleted the registry entry {entry_file}; sbx-add sbx1 "{tmp_path / "one dir"}" '
        "registers the directory again",
        f"sbx-rm: the container sbx-sbx1 is gone; nothing in {tmp_path / 'one dir'} was changed",
    ]


def test_a_delete_that_fails_is_named_and_the_container_is_already_gone(run_rm, entry_file, registry, recorder):
    if os.geteuid() == 0:
        pytest.skip("root can delete from a read-only directory")

    registry.chmod(0o555)

    try:
        exit_code, out, err = run_rm(["sbx1", "--unregister"])
    finally:
        registry.chmod(0o755)

    assert exit_code == 1
    assert err.startswith(f"sbx-rm: could not delete {entry_file}; the container is gone and nothing in ")
    assert "is gone; nothing in" not in out
    assert len(_down_call_list(recorder)) == 1
    assert entry_file.is_file()


# ------------------------------------------------------------------------------
# A broken entry
# ------------------------------------------------------------------------------

def test_a_broken_entry_without_unregister_is_refused_with_the_hint_and_kept(run_rm, broken_entry_file, recorder):
    before = broken_entry_file.read_bytes()

    exit_code, _, err = run_rm(["sbx1", "--yes"])

    assert exit_code == 1
    assert err.splitlines() == [
        f"sbx-rm: the entry {broken_entry_file} has no absolute path",
        "sbx-rm: the entry is broken, so sbx-sbx1 cannot be taken down with Compose; "
        "sbx-rm sbx1 --unregister removes the container by name and clears the entry",
    ]
    assert recorder.call_list == []
    assert broken_entry_file.read_bytes() == before


def test_a_broken_entry_with_unregister_stops_and_removes_the_container_by_name_and_deletes_the_entry(
    run_rm, broken_entry_file, recorder
):
    exit_code, out, err = run_rm(["sbx1", "--unregister"])

    assert exit_code == 0, err
    assert [call[0] for call in recorder.call_list] == ["info", "container", "container", "stop", "rm"]
    assert recorder.call_list[1] == ["container", "inspect", "sbx-sbx1"]
    assert recorder.call_list[3] == ["stop", "sbx-sbx1"]
    assert recorder.call_list[4] == ["rm", "sbx-sbx1"]
    assert _down_call_list(recorder) == []
    assert not broken_entry_file.exists()
    assert out.splitlines() == [
        f"sbx-rm: the entry {broken_entry_file} is broken; removing the container sbx-sbx1 by name",
        f"sbx-rm: deleted the registry entry {broken_entry_file}; sbx-add sbx1 HOST_PATH registers the sandbox again",
        "sbx-rm: the container sbx-sbx1 is gone; nothing in the sandbox directory was changed",
    ]


def test_a_broken_entry_whose_container_is_gone_only_clears_the_entry(run_rm, broken_entry_file, recorder):
    recorder.answer(["container", "inspect", "sbx-sbx1"], DockerResult(1, ""))

    exit_code, out, _ = run_rm(["sbx1", "--unregister"])

    assert exit_code == 0
    assert not any(call[0] in ("stop", "rm") for call in recorder.call_list)
    assert not broken_entry_file.exists()
    assert "removing the container" not in out


def test_a_broken_entry_with_docker_not_answering_is_kept(run_rm, broken_entry_file, recorder):
    recorder.answer(["info"], DockerResult(1, ""))

    exit_code, _, err = run_rm(["sbx1", "--unregister", "--yes"])

    assert exit_code == 1
    assert err == "sbx-rm: cannot reach Docker; is Docker running?\n"
    assert broken_entry_file.is_file()
    assert not any(call[0] in ("stop", "rm") for call in recorder.call_list)


def test_a_running_container_of_a_broken_entry_needs_yes_or_a_terminal(run_rm, broken_entry_file, recorder):
    _set_running(recorder)

    exit_code, _, err = run_rm(["sbx1", "--unregister"])

    assert exit_code == 1
    assert err == NO_TERMINAL_TEXT
    assert broken_entry_file.is_file()
    assert not any(call[0] in ("stop", "rm") for call in recorder.call_list)


def test_a_running_container_of_a_broken_entry_goes_with_yes(run_rm, broken_entry_file, recorder):
    _set_running(recorder)

    exit_code, out, _ = run_rm(["sbx1", "--unregister", "--yes"])

    assert exit_code == 0
    assert WARNING_TEXT in out
    assert ["stop", "sbx-sbx1"] in recorder.call_list
    assert not broken_entry_file.exists()


def test_a_failed_stop_keeps_the_entry(run_rm, broken_entry_file, recorder):
    recorder.answer(["stop"], DockerResult(1, ""))

    exit_code, _, err = run_rm(["sbx1", "--unregister"])

    assert exit_code == 1
    assert err == "sbx-rm: docker stop failed for sbx-sbx1; the registry entry stays\n"
    assert ["rm", "sbx-sbx1"] not in recorder.call_list
    assert broken_entry_file.is_file()


def test_a_failed_rm_keeps_the_entry(run_rm, broken_entry_file, recorder):
    recorder.answer(["rm"], DockerResult(1, ""))

    exit_code, _, err = run_rm(["sbx1", "--unregister"])

    assert exit_code == 1
    assert err == "sbx-rm: Docker could not remove the container sbx-sbx1; the registry entry stays\n"
    assert broken_entry_file.is_file()


def test_an_entry_file_whose_name_breaks_the_rule_is_refused_and_kept(run_rm, registry, recorder):
    bad_file = write_json_entry(registry, "Bad_Name", "relative/dir", "claude")

    exit_code, _, err = run_rm(["Bad_Name", "--unregister", "--yes"])

    assert exit_code == 1
    assert "breaks the sandbox name rule" in err
    assert bad_file.is_file()
    assert recorder.call_list == []


# ------------------------------------------------------------------------------
# Only rm deletes
# ------------------------------------------------------------------------------

def test_a_good_entry_is_never_deleted_without_unregister(run_rm, entry_file, recorder):
    run_rm(["sbx1", "--yes"])

    assert entry_file.is_file()
