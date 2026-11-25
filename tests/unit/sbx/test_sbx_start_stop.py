# --------------------------------------------------------------------------------
# Tests of sbx-start and sbx-stop
# --------------------------------------------------------------------------------
# Real registry files and directories under tmp_path; Docker is the recorder, so a
# refusal before Docker is proven by an empty call list.
# --------------------------------------------------------------------------------

from pathlib import Path

import pytest

from sbx import start as start_module
from sbx import stop as stop_module
from sbx.docker import DockerResult
from sbx_helpers import REPO_DIR, environ_for, write_json_entry

RUNNING_PREFIX = ["container", "inspect", "--format", "{{.State.Running}}"]
RUNNING_IMAGE_PREFIX = ["container", "inspect", "--format", "{{.Image}}"]
CURRENT_IMAGE_PREFIX = ["image", "inspect", "--format", "{{.Id}}"]
RULE_TEXT = "breaks the sandbox name rule"


@pytest.fixture
def sandbox_dir(registry, tmp_path):
    project_dir = tmp_path / "one dir"
    (project_dir / "sbx1").mkdir(parents=True)
    (project_dir / "state").mkdir()
    write_json_entry(registry, "sbx1", str(project_dir), "cursor")

    return project_dir


# --------------------------------------------------------------------------------

@pytest.fixture
def run_start(config_dir, recorder, capsys):
    def run(argument_list, extra_map=None):
        environ = environ_for(config_dir, extra_map)
        exit_code = start_module.main(argument_list, environ, docker=recorder, repo_dir=REPO_DIR)
        captured = capsys.readouterr()

        return exit_code, captured.out, captured.err

    return run


# --------------------------------------------------------------------------------

@pytest.fixture
def run_stop(config_dir, recorder, capsys):
    def run(argument_list, extra_map=None):
        environ = environ_for(config_dir, extra_map)
        exit_code = stop_module.main(argument_list, environ, docker=recorder, repo_dir=REPO_DIR)
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
# Usage and names, for both commands
# --------------------------------------------------------------------------------

@pytest.mark.parametrize("command_name", ["start", "stop"])
@pytest.mark.parametrize("argument_list", [[], ["one", "two"]])
def test_a_wrong_argument_count_prints_the_usage_and_does_not_reach_docker(
    command_name, argument_list, run_start, run_stop, recorder
):
    run = run_start if command_name == "start" else run_stop

    exit_code, out, err = run(argument_list)

    assert exit_code == 2
    assert out == ""
    assert err == f"Usage: sbx-{command_name} NAME\n"
    assert recorder.call_list == []


# --------------------------------------------------------------------------------

@pytest.mark.parametrize("command_name", ["start", "stop"])
def test_an_unregistered_name_is_refused_with_the_add_advice(command_name, run_start, run_stop, recorder):
    run = run_start if command_name == "start" else run_stop

    exit_code, _, err = run(["nosuch"])

    assert exit_code == 1
    assert err == f"sbx-{command_name}: nosuch is not registered; run: sbx-add nosuch HOST_PATH\n"
    assert recorder.call_list == []


# --------------------------------------------------------------------------------

@pytest.mark.parametrize("command_name", ["start", "stop"])
@pytest.mark.parametrize("name", ["../x", "Demo", "", "ok\nbad"])
def test_a_name_that_breaks_the_rule_is_refused_before_the_registry_is_read(
    command_name, name, run_start, run_stop, recorder
):
    run = run_start if command_name == "start" else run_stop

    exit_code, _, err = run([name])

    assert exit_code == 1
    assert RULE_TEXT in err
    assert recorder.call_list == []


# --------------------------------------------------------------------------------

@pytest.mark.parametrize("command_name", ["start", "stop"])
def test_a_tag_other_than_local_or_test_is_refused_first(command_name, run_start, run_stop, sandbox_dir, recorder):
    run = run_start if command_name == "start" else run_stop

    exit_code, _, err = run(["sbx1"], {"SBX_IMAGE_TAG": "latest"})

    assert exit_code == 1
    assert err == f"sbx-{command_name}: SBX_IMAGE_TAG must be local or test, not 'latest'\n"
    assert recorder.call_list == []


# --------------------------------------------------------------------------------

@pytest.mark.parametrize("command_name", ["start", "stop"])
def test_a_broken_entry_is_refused_with_its_own_error(command_name, run_start, run_stop, registry, recorder):
    (registry / "sbx1.json").write_text("[]")
    run = run_start if command_name == "start" else run_stop

    exit_code, _, err = run(["sbx1"])

    assert exit_code == 1
    assert err == f"sbx-{command_name}: the entry {registry / 'sbx1.json'} is not a JSON object\n"
    assert recorder.call_list == []


# --------------------------------------------------------------------------------
# sbx-start refusals, in order
# --------------------------------------------------------------------------------

@pytest.mark.parametrize("missing_dir", ["sbx1", "state"])
def test_start_refuses_a_missing_directory_before_any_docker_call(
    run_start, sandbox_dir, registry, recorder, missing_dir
):
    Path(f"{sandbox_dir}/{missing_dir}").rmdir()

    exit_code, _, err = run_start(["sbx1"])

    assert exit_code == 1
    assert err == (
        f"sbx-start: missing {sandbox_dir}/{missing_dir}; create it with mkdir -p, "
        f"or fix the path in {registry / 'sbx1.json'}\n"
    )
    assert recorder.call_list == []


# --------------------------------------------------------------------------------

def test_start_refuses_when_docker_does_not_answer_and_does_not_advise_upgrade(run_start, sandbox_dir, recorder):
    recorder.answer(["info"], DockerResult(1, ""))

    exit_code, _, err = run_start(["sbx1"])

    assert exit_code == 1
    assert err == "sbx-start: cannot reach Docker; is Docker running?\n"
    assert "sbx-upgrade" not in err
    assert _compose_call_list(recorder) == []


# --------------------------------------------------------------------------------

def test_start_refuses_a_missing_image_and_names_the_image_and_upgrade(run_start, sandbox_dir, recorder):
    recorder.answer(["image", "inspect"], DockerResult(1, ""))

    exit_code, _, err = run_start(["sbx1"])

    assert exit_code == 1
    assert err == (
        "sbx-start: sbx-cursor:local is not built; run: sbx-upgrade sbx1 "
        "(it builds the images and starts the sandbox)\n"
    )
    assert _compose_call_list(recorder) == []


# --------------------------------------------------------------------------------

def test_start_names_the_logs_when_compose_up_fails(run_start, sandbox_dir, recorder):
    recorder.answer(["compose"], DockerResult(1, ""))

    exit_code, _, err = run_start(["sbx1"])

    assert exit_code == 1
    assert err == "sbx-start: docker compose up failed; docker logs sbx-sbx1 shows why\n"


# --------------------------------------------------------------------------------
# sbx-start success
# --------------------------------------------------------------------------------

def test_start_prints_the_three_lines_and_runs_up_once(run_start, sandbox_dir, recorder):
    exit_code, out, err = run_start(["sbx1"])

    assert exit_code == 0
    assert err == ""
    assert out.splitlines() == [
        "sbx-start: sbx-sbx1 is running",
        "sbx-start: open a shell with: sbx-shell sbx1",
        "sbx-start: in a new or recreated container, run sbx-init there before the agent",
    ]
    assert _compose_call_list(recorder) == [
        [
            "compose", "--env-file", "/dev/null", "-p", "sbx-sbx1", "-f", f"{REPO_DIR}/compose.yml",
            "up", "-d", "--wait",
        ]
    ]


# --------------------------------------------------------------------------------

def test_start_hands_the_entry_and_the_tag_to_compose_and_not_the_caller_values(run_start, sandbox_dir, recorder):
    ambient_map = {"SBX_DIR": "/ambient", "SBX_AGENT": "claude", "COMPOSE_PROJECT_NAME": "ambient", "SBX_IMAGE_TAG": "test"}

    run_start(["sbx1"], ambient_map)

    compose_environ = recorder.environ_list[recorder.call_list.index(_compose_call_list(recorder)[0])]

    assert compose_environ["SBX_DIR"] == str(sandbox_dir)
    assert compose_environ["SBX_AGENT"] == "cursor"
    assert compose_environ["SBX_NAME"] == "sbx1"
    assert compose_environ["SBX_IMAGE_TAG"] == "test"
    assert "COMPOSE_PROJECT_NAME" not in compose_environ


# --------------------------------------------------------------------------------

def test_start_checks_the_image_of_the_agent_and_the_tag(run_start, sandbox_dir, recorder):
    exit_code, _, err = run_start(["sbx1"], {"SBX_IMAGE_TAG": "test"})

    assert exit_code == 0
    assert err.startswith("sbx-start: using the test images because SBX_IMAGE_TAG=test")
    assert ["image", "inspect", "sbx-cursor:test"] in recorder.call_list


# --------------------------------------------------------------------------------

def test_start_warns_before_up_when_the_sandbox_runs_on_an_older_image(run_start, sandbox_dir, recorder):
    recorder.answer(RUNNING_PREFIX, DockerResult(0, "true\n"))
    recorder.answer(RUNNING_IMAGE_PREFIX, DockerResult(0, "sha256:old\n"))
    recorder.answer(CURRENT_IMAGE_PREFIX, DockerResult(0, "sha256:new\n"))

    exit_code, out, _ = run_start(["sbx1"])

    assert exit_code == 0
    assert out.splitlines()[0] == (
        "sbx-start: sbx-sbx1 runs on an older image; recreating it on the new one "
        "will close its open shells and Claude sessions"
    )
    assert len(_compose_call_list(recorder)) == 1


# --------------------------------------------------------------------------------
# sbx-stop
# --------------------------------------------------------------------------------

def test_stop_runs_compose_stop_with_the_environment_of_the_entry(run_stop, sandbox_dir, recorder):
    exit_code, out, err = run_stop(["sbx1"])

    assert exit_code == 0
    assert err == ""
    assert out == f"sbx-stop: sbx-sbx1 is stopped; nothing in {sandbox_dir} was changed\n"
    assert _compose_call_list(recorder) == [
        ["compose", "--env-file", "/dev/null", "-p", "sbx-sbx1", "-f", f"{REPO_DIR}/compose.yml", "stop"]
    ]

    compose_environ = recorder.environ_list[0]

    assert compose_environ["SBX_DIR"] == str(sandbox_dir)
    assert compose_environ["SBX_AGENT"] == "cursor"


# --------------------------------------------------------------------------------

def test_stop_drops_the_compose_keys_of_the_caller(run_stop, sandbox_dir, recorder):
    run_stop(["sbx1"], {"COMPOSE_FILE": "/ambient/compose.yml", "COMPOSE_PROFILES": "ambient"})

    for key in recorder.environ_list[0]:
        assert not key.startswith("COMPOSE_")


# --------------------------------------------------------------------------------

def test_a_failing_stop_is_named(run_stop, sandbox_dir, recorder):
    recorder.answer(["compose"], DockerResult(1, ""))

    exit_code, out, err = run_stop(["sbx1"])

    assert exit_code == 1
    assert out == ""
    assert err == "sbx-stop: docker compose stop failed for sbx-sbx1\n"


# --------------------------------------------------------------------------------

def test_stop_works_when_the_project_directory_has_moved(run_stop, sandbox_dir, recorder):
    Path(f"{sandbox_dir}/sbx1").rmdir()

    exit_code, _, _ = run_stop(["sbx1"])

    assert exit_code == 0
