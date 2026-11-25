# --------------------------------------------------------------------------------
# Tests of sbx-shell
# --------------------------------------------------------------------------------
# Docker is the recorder and the final exec is a recording function, so no case
# reaches a daemon or replaces the test process.
# --------------------------------------------------------------------------------

from pathlib import Path

import pytest

from sbx import shell as shell_module
from sbx.docker import DockerResult
from sbx_helpers import REPO_DIR, environ_for, write_json_entry

RUNNING_PREFIX = ["container", "inspect", "--format", "{{.State.Running}}"]
EXEC_ARGUMENT_LIST = ["docker", "exec", "-it", "-w", "/home/sandbox/workspace/sbx1", "sbx-sbx1", "bash"]
RULE_TEXT = "breaks the sandbox name rule"


class ExecRecorder:
    def __init__(self) -> None:
        self.call_list: list[tuple[str, list[str], dict[str, str]]] = []

    # --------------------------------------------------------------------------------

    def __call__(self, file: str, argument_list: list[str], environ: dict[str, str]) -> None:
        self.call_list.append((file, list(argument_list), dict(environ)))


# --------------------------------------------------------------------------------

@pytest.fixture
def exec_recorder() -> ExecRecorder:
    return ExecRecorder()


# --------------------------------------------------------------------------------

@pytest.fixture
def sandbox_dir(registry, tmp_path):
    project_dir = tmp_path / "one dir"
    (project_dir / "sbx1").mkdir(parents=True)
    (project_dir / "state").mkdir()
    write_json_entry(registry, "sbx1", str(project_dir), "claude")

    return project_dir


# --------------------------------------------------------------------------------

@pytest.fixture
def run_shell(config_dir, recorder, exec_recorder, capsys):
    def run(argument_list, extra_map=None):
        environ = environ_for(config_dir, extra_map)
        exit_code = shell_module.main(
            argument_list, environ, docker=recorder, repo_dir=REPO_DIR, exec_function=exec_recorder
        )
        captured = capsys.readouterr()

        return exit_code, captured.out, captured.err

    return run


# --------------------------------------------------------------------------------

def _compose_call_list(recorder):
    compose_list = []

    for call in recorder.call_list:
        if call[0] == "compose":
            compose_list.append(call)

    return compose_list


# --------------------------------------------------------------------------------
# Refusals
# --------------------------------------------------------------------------------

@pytest.mark.parametrize("argument_list", [[], ["one", "two"]])
def test_a_wrong_argument_count_prints_the_usage_and_does_nothing(run_shell, recorder, exec_recorder, argument_list):
    exit_code, out, err = run_shell(argument_list)

    assert exit_code == 2
    assert out == ""
    assert err == "Usage: sbx-shell NAME\n"
    assert recorder.call_list == []
    assert exec_recorder.call_list == []


# --------------------------------------------------------------------------------

def test_an_unregistered_name_is_refused_with_the_add_advice(run_shell, exec_recorder):
    exit_code, _, err = run_shell(["nosuch"])

    assert exit_code == 1
    assert err == "sbx-shell: nosuch is not registered; run: sbx-add nosuch HOST_PATH\n"
    assert exec_recorder.call_list == []


# --------------------------------------------------------------------------------

@pytest.mark.parametrize("name", ["../x", "Demo", "", "ok\nbad"])
def test_a_name_that_breaks_the_rule_is_refused_before_docker(run_shell, recorder, exec_recorder, name):
    exit_code, _, err = run_shell([name])

    assert exit_code == 1
    assert RULE_TEXT in err
    assert recorder.call_list == []
    assert exec_recorder.call_list == []


# --------------------------------------------------------------------------------

def test_a_tag_other_than_local_or_test_is_refused_first(run_shell, sandbox_dir, recorder, exec_recorder):
    exit_code, _, err = run_shell(["sbx1"], {"SBX_IMAGE_TAG": "latest"})

    assert exit_code == 1
    assert err == "sbx-shell: SBX_IMAGE_TAG must be local or test, not 'latest'\n"
    assert recorder.call_list == []
    assert exec_recorder.call_list == []


# --------------------------------------------------------------------------------

@pytest.mark.parametrize("missing_dir", ["sbx1", "state"])
def test_a_missing_directory_is_refused_before_compose_and_the_exec(
    run_shell, sandbox_dir, registry, recorder, exec_recorder, missing_dir
):
    Path(f"{sandbox_dir}/{missing_dir}").rmdir()

    exit_code, _, err = run_shell(["sbx1"])

    assert exit_code == 1
    assert err == (
        f"sbx-shell: missing {sandbox_dir}/{missing_dir}; create it with mkdir -p, "
        f"or fix the path in {registry / 'sbx1.json'}\n"
    )
    assert _compose_call_list(recorder) == []
    assert exec_recorder.call_list == []


# --------------------------------------------------------------------------------

def test_docker_not_answering_is_refused_before_compose_and_the_exec_without_upgrade_advice(
    run_shell, sandbox_dir, recorder, exec_recorder
):
    recorder.answer(["info"], DockerResult(1, ""))

    exit_code, _, err = run_shell(["sbx1"])

    assert exit_code == 1
    assert err == "sbx-shell: cannot reach Docker; is Docker running?\n"
    assert "sbx-upgrade" not in err
    assert _compose_call_list(recorder) == []
    assert exec_recorder.call_list == []


# --------------------------------------------------------------------------------

def test_a_missing_image_is_refused_before_compose_and_the_exec(run_shell, sandbox_dir, recorder, exec_recorder):
    recorder.answer(["image", "inspect"], DockerResult(1, ""))

    exit_code, _, err = run_shell(["sbx1"])

    assert exit_code == 1
    assert "sbx-claude:local is not built; run: sbx-upgrade sbx1" in err
    assert _compose_call_list(recorder) == []
    assert exec_recorder.call_list == []


# --------------------------------------------------------------------------------

def test_a_failing_up_is_refused_before_the_exec(run_shell, sandbox_dir, recorder, exec_recorder):
    recorder.answer(["compose"], DockerResult(1, ""))

    exit_code, _, err = run_shell(["sbx1"])

    assert exit_code == 1
    assert err == "sbx-shell: docker compose up failed; docker logs sbx-sbx1 shows why\n"
    assert exec_recorder.call_list == []


# --------------------------------------------------------------------------------
# Opening the shell
# --------------------------------------------------------------------------------

def test_a_running_sandbox_never_calls_compose_and_ends_in_one_exec_of_docker_exec(
    run_shell, sandbox_dir, recorder, exec_recorder
):
    recorder.answer(RUNNING_PREFIX, DockerResult(0, "true\n"))

    exit_code, out, _ = run_shell(["sbx1"])

    assert exit_code == 0
    assert out == ""
    assert _compose_call_list(recorder) == []
    assert len(exec_recorder.call_list) == 1

    file, argument_list, _ = exec_recorder.call_list[0]

    assert file == "docker"
    assert argument_list == EXEC_ARGUMENT_LIST


# --------------------------------------------------------------------------------

def test_a_stopped_sandbox_is_brought_up_and_then_the_same_exec_runs(run_shell, sandbox_dir, recorder, exec_recorder):
    recorder.answer(RUNNING_PREFIX, DockerResult(0, "false\n"))

    exit_code, _, _ = run_shell(["sbx1"])

    compose_list = _compose_call_list(recorder)

    assert exit_code == 0
    assert len(compose_list) == 1
    assert compose_list[0][-3:] == ["up", "-d", "--wait"]
    assert len(exec_recorder.call_list) == 1
    assert exec_recorder.call_list[0][1] == EXEC_ARGUMENT_LIST


# --------------------------------------------------------------------------------

def test_a_sandbox_with_no_container_is_brought_up_and_then_the_exec_runs(
    run_shell, sandbox_dir, recorder, exec_recorder
):
    recorder.answer(RUNNING_PREFIX, DockerResult(1, ""))

    run_shell(["sbx1"])

    assert len(_compose_call_list(recorder)) == 1
    assert len(exec_recorder.call_list) == 1


# --------------------------------------------------------------------------------

def test_the_exec_gets_the_environment_of_the_caller(run_shell, sandbox_dir, recorder, exec_recorder):
    recorder.answer(RUNNING_PREFIX, DockerResult(0, "true\n"))

    run_shell(["sbx1"], {"TERM": "xterm-256color"})

    assert exec_recorder.call_list[0][2]["TERM"] == "xterm-256color"


# --------------------------------------------------------------------------------

def test_the_exec_is_the_last_call_and_comes_after_up(run_shell, sandbox_dir, recorder, exec_recorder):
    recorder.answer(RUNNING_PREFIX, DockerResult(0, "false\n"))

    run_shell(["sbx1"])

    assert recorder.call_list[-1][0] == "compose"
    assert len(exec_recorder.call_list) == 1
