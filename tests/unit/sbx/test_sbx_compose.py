# --------------------------------------------------------------------------------
# Tests of the Compose layer in sbx/docker.py
# --------------------------------------------------------------------------------
# compose_command is pure, so its hand-off of the agent, the tag and the directory
# is proven on its result. The rest runs against the Docker recorder.
# --------------------------------------------------------------------------------

from pathlib import Path

import pytest

from sbx.cli import SbxError
from sbx.docker import (
    DockerResult,
    bring_up_sandbox,
    check_sandbox_dirs,
    compose_command,
    require_docker,
    require_images,
    run_compose,
    warn_sessions_close,
)
from sbx.registry import Entry
from sbx_helpers import REPO_DIR

AMBIENT_MAP = {
    "COMPOSE_PROJECT_NAME": "ambient-project",
    "COMPOSE_FILE": "/ambient/compose.yml",
    "COMPOSE_PROFILES": "ambient",
    "SBX_DIR": "/ambient",
    "SBX_AGENT": "ambient",
    "SBX_NAME": "ambient",
    "SBX_IMAGE_TAG": "ambient",
    "PATH": "/usr/bin",
}
RUNNING_PREFIX = ["container", "inspect", "--format", "{{.State.Running}}"]
RUNNING_IMAGE_PREFIX = ["container", "inspect", "--format", "{{.Image}}"]
CURRENT_IMAGE_PREFIX = ["image", "inspect", "--format", "{{.Id}}"]


def _compose_call_list(recorder):
    compose_list = []

    for call in recorder.call_list:
        if call[0] == "compose":
            compose_list.append(call)

    return compose_list


@pytest.fixture
def entry(tmp_path):
    sandbox_dir = tmp_path / "one dir"
    (sandbox_dir / "sbx1").mkdir(parents=True)
    (sandbox_dir / "state").mkdir()

    return Entry("sbx1", str(sandbox_dir), "cursor")


# --------------------------------------------------------------------------------
# compose_command
# --------------------------------------------------------------------------------

def test_compose_command_builds_the_arguments_for_the_project_of_the_sandbox():
    argument_list, _ = compose_command(Entry("sbx1", "/x/one dir", "cursor"), "test", REPO_DIR, ["up", "-d", "--wait"], {})

    assert argument_list == [
        "compose", "--env-file", "/dev/null", "-p", "sbx-sbx1", "-f", f"{REPO_DIR}/compose.yml", "up", "-d", "--wait",
    ]


def test_compose_command_takes_the_sbx_values_from_the_entry_and_the_checked_tag():
    _, environ = compose_command(Entry("sbx1", "/x/one dir", "cursor"), "test", REPO_DIR, ["stop"], AMBIENT_MAP)

    assert environ["SBX_NAME"] == "sbx1"
    assert environ["SBX_DIR"] == "/x/one dir"
    assert environ["SBX_AGENT"] == "cursor"
    assert environ["SBX_IMAGE_TAG"] == "test"


def test_compose_command_drops_every_compose_key_of_the_caller():
    _, environ = compose_command(Entry("sbx1", "/x/one", "claude"), "local", REPO_DIR, ["stop"], AMBIENT_MAP)

    for key in environ:
        assert not key.startswith("COMPOSE_")


def test_compose_command_keeps_the_other_keys_of_the_caller():
    _, environ = compose_command(Entry("sbx1", "/x/one", "claude"), "local", REPO_DIR, ["stop"], AMBIENT_MAP)

    assert environ["PATH"] == "/usr/bin"


def test_compose_command_does_not_change_the_caller_mapping():
    caller_map = dict(AMBIENT_MAP)

    compose_command(Entry("sbx1", "/x/one", "claude"), "local", REPO_DIR, ["stop"], caller_map)

    assert caller_map == AMBIENT_MAP


@pytest.mark.parametrize("agent", ["claude", "cursor"])
def test_the_ambient_agent_never_reaches_compose_whatever_the_agent_of_the_entry(agent):
    _, environ = compose_command(Entry("sbx1", "/x/one", agent), "local", REPO_DIR, ["stop"], AMBIENT_MAP)

    assert environ["SBX_AGENT"] == agent


# --------------------------------------------------------------------------------
# run_compose
# --------------------------------------------------------------------------------

def test_run_compose_passes_the_command_and_its_environment_to_docker(recorder):
    entry = Entry("sbx1", "/x/one", "claude")

    run_compose(recorder, entry, "local", REPO_DIR, ["stop"], AMBIENT_MAP)

    assert recorder.call_list == [
        ["compose", "--env-file", "/dev/null", "-p", "sbx-sbx1", "-f", f"{REPO_DIR}/compose.yml", "stop"]
    ]
    assert recorder.environ_list[0]["SBX_DIR"] == "/x/one"
    assert recorder.capture_list == [False]


def test_run_compose_returns_what_docker_answered(recorder):
    recorder.answer(["compose"], DockerResult(3, ""))

    result = run_compose(recorder, Entry("sbx1", "/x/one", "claude"), "local", REPO_DIR, ["stop"], {})

    assert result.returncode == 3


# --------------------------------------------------------------------------------
# The directories
# --------------------------------------------------------------------------------

def test_check_sandbox_dirs_passes_when_both_directories_exist(entry, registry):
    check_sandbox_dirs(entry, registry)


@pytest.mark.parametrize("missing_dir", ["sbx1", "state"])
def test_check_sandbox_dirs_names_the_missing_directory_and_the_entry_file(entry, registry, missing_dir):
    (registry / "sbx1.json").write_text("{}")
    Path(f"{entry.path}/{missing_dir}").rmdir()

    with pytest.raises(SbxError) as error:
        check_sandbox_dirs(entry, registry)

    assert str(error.value) == (
        f"missing {entry.path}/{missing_dir}; create it with mkdir -p, or fix the path in {registry / 'sbx1.json'}"
    )


# --------------------------------------------------------------------------------
# Docker and the images
# --------------------------------------------------------------------------------

def test_require_docker_passes_when_docker_answers(recorder):
    require_docker(recorder)

    assert recorder.call_list == [["info"]]


def test_require_docker_refuses_when_docker_does_not_answer(recorder):
    recorder.answer(["info"], DockerResult(1, ""))

    with pytest.raises(SbxError) as error:
        require_docker(recorder)

    assert str(error.value) == "cannot reach Docker; is Docker running?"


def test_require_images_asks_docker_before_the_image(recorder, entry):
    recorder.answer(["info"], DockerResult(1, ""))

    with pytest.raises(SbxError) as error:
        require_images(recorder, entry, "local")

    assert "sbx-upgrade" not in str(error.value)
    assert recorder.call_list == [["info"]]


def test_require_images_refuses_a_missing_image_with_the_upgrade_advice(recorder, entry):
    recorder.answer(["image", "inspect"], DockerResult(1, ""))

    with pytest.raises(SbxError) as error:
        require_images(recorder, entry, "local")

    assert str(error.value) == (
        "sbx-cursor:local is not built; run: sbx-upgrade sbx1 (it builds the images and starts the sandbox)"
    )


def test_require_images_checks_the_image_of_the_agent_and_the_tag(recorder, entry):
    require_images(recorder, entry, "test")

    assert recorder.call_list == [["info"], ["image", "inspect", "sbx-cursor:test"]]


# --------------------------------------------------------------------------------
# The warning
# --------------------------------------------------------------------------------

def test_warn_sessions_close_prints_one_line_on_stdout(capsys):
    warn_sessions_close("sbx-upgrade", "demo", "is running; after the build, recreating it")

    captured = capsys.readouterr()

    assert captured.out == (
        "sbx-upgrade: sbx-demo is running; after the build, recreating it "
        "will close its open shells and Claude sessions\n"
    )
    assert captured.err == ""


# --------------------------------------------------------------------------------
# bring_up_sandbox
# --------------------------------------------------------------------------------

def test_bring_up_sandbox_checks_directories_before_any_docker_call(recorder, entry, registry):
    (registry / "sbx1.json").write_text("{}")
    Path(f"{entry.path}/state").rmdir()

    with pytest.raises(SbxError):
        bring_up_sandbox("sbx-start", recorder, entry, "local", REPO_DIR, registry, {})

    assert recorder.call_list == []


def test_bring_up_sandbox_runs_up_with_the_output_inherited(recorder, entry, registry):
    bring_up_sandbox("sbx-start", recorder, entry, "local", REPO_DIR, registry, {})

    compose_list = _compose_call_list(recorder)

    assert len(compose_list) == 1
    assert compose_list[0][-3:] == ["up", "-d", "--wait"]
    assert recorder.capture_list[recorder.call_list.index(compose_list[0])] is False


def test_bring_up_sandbox_warns_before_up_when_the_running_container_is_on_an_older_image(
    recorder, entry, registry, capsys
):
    recorder.answer(RUNNING_PREFIX, DockerResult(0, "true\n"))
    recorder.answer(RUNNING_IMAGE_PREFIX, DockerResult(0, "sha256:old\n"))
    recorder.answer(CURRENT_IMAGE_PREFIX, DockerResult(0, "sha256:new\n"))

    bring_up_sandbox("sbx-start", recorder, entry, "local", REPO_DIR, registry, {})

    assert capsys.readouterr().out == (
        "sbx-start: sbx-sbx1 runs on an older image; recreating it on the new one "
        "will close its open shells and Claude sessions\n"
    )


def test_bring_up_sandbox_does_not_warn_when_the_image_is_current(recorder, entry, registry, capsys):
    recorder.answer(RUNNING_PREFIX, DockerResult(0, "true\n"))
    recorder.answer(RUNNING_IMAGE_PREFIX, DockerResult(0, "sha256:same\n"))
    recorder.answer(CURRENT_IMAGE_PREFIX, DockerResult(0, "sha256:same\n"))

    bring_up_sandbox("sbx-start", recorder, entry, "local", REPO_DIR, registry, {})

    assert capsys.readouterr().out == ""


def test_bring_up_sandbox_names_the_logs_when_up_fails(recorder, entry, registry):
    recorder.answer(["compose"], DockerResult(1, ""))

    with pytest.raises(SbxError) as error:
        bring_up_sandbox("sbx-start", recorder, entry, "local", REPO_DIR, registry, {})

    assert str(error.value) == "docker compose up failed; docker logs sbx-sbx1 shows why"
