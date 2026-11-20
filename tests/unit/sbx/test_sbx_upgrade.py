# ------------------------------------------------------------------------------
# Tests of sbx-upgrade
# ------------------------------------------------------------------------------
# Real registry files and directories under tmp_path. Docker is the recorder and
# the build is a stub function, so the refusals, the failures and the options are
# proven without Docker. The warning, the recreate and the closing lines are proven
# on real Docker in tests/integration.
# ------------------------------------------------------------------------------

import inspect
from pathlib import Path

import pytest

from sbx import build as build_module
from sbx import upgrade as upgrade_module
from sbx.docker import DockerResult
from sbx_helpers import REPO_DIR, environ_for, write_json_entry

RULE_TEXT = "breaks the sandbox name rule"
VERSIONS_PREFIX = ["exec", "sbx-sbx1", "cat", "/etc/sbx/tool-versions"]


# ------------------------------------------------------------------------------
# Fixtures and stand-ins
# ------------------------------------------------------------------------------

class BuildStub:
    # Stands in for the build function: notes what it got, prints a line so a test
    # sees whether it ran, and answers a fixed code.
    def __init__(self, recorder, exit_code: int = 0) -> None:
        self.recorder = recorder
        self.exit_code = exit_code
        self.option_list_list: list[list[str]] = []
        self.docker_call_count_list: list[int] = []
        self.repo_dir_list: list[Path] = []

    def __call__(self, option_list, environ, docker, repo_dir) -> int:
        self.option_list_list.append(list(option_list))
        self.docker_call_count_list.append(len(self.recorder.call_list))
        self.repo_dir_list.append(repo_dir)
        print("BUILD RAN")

        return self.exit_code


@pytest.fixture
def sandbox_dir(registry, tmp_path):
    project_dir = tmp_path / "one dir"
    (project_dir / "sbx1").mkdir(parents=True)
    (project_dir / "state").mkdir()
    write_json_entry(registry, "sbx1", str(project_dir), "cursor")

    return project_dir


@pytest.fixture
def build_stub(recorder) -> BuildStub:
    return BuildStub(recorder)


@pytest.fixture
def run_upgrade(config_dir, recorder, build_stub, capsys):
    def run(argument_list, extra_map=None, stub=None):
        environ = environ_for(config_dir, extra_map)
        exit_code = upgrade_module.main(
            argument_list, environ, docker=recorder, repo_dir=REPO_DIR, build_function=stub or build_stub
        )
        captured = capsys.readouterr()

        return exit_code, captured.out, captured.err

    return run


def _compose_call_list(recorder):
    compose_list = []

    for call in recorder.call_list:
        if call[0] == "compose":
            compose_list.append(call)

    return compose_list


# ------------------------------------------------------------------------------
# Refusals, all before the build
# ------------------------------------------------------------------------------

def test_no_argument_prints_the_usage_and_does_not_build(run_upgrade, build_stub, recorder):
    exit_code, out, err = run_upgrade([])

    assert exit_code == 2
    assert out == ""
    assert err == "Usage: sbx-upgrade NAME [BUILD_OPTION...]\n"
    assert build_stub.option_list_list == []
    assert recorder.call_list == []


def test_an_unregistered_name_is_refused_before_the_build(run_upgrade, build_stub, recorder):
    exit_code, out, err = run_upgrade(["nosuch"])

    assert exit_code == 1
    assert out == ""
    assert err == "sbx-upgrade: nosuch is not registered; run: sbx-add nosuch HOST_PATH\n"
    assert build_stub.option_list_list == []
    assert recorder.call_list == []


@pytest.mark.parametrize("name", ["../x", "Demo", "ok\nbad"])
def test_a_name_that_breaks_the_rule_is_refused_before_the_build(name, run_upgrade, build_stub, recorder):
    exit_code, _, err = run_upgrade([name, "--no-cache"])

    assert exit_code == 1
    assert RULE_TEXT in err
    assert build_stub.option_list_list == []
    assert recorder.call_list == []


@pytest.mark.parametrize("missing_dir", ["sbx1", "state"])
def test_a_missing_directory_is_refused_before_the_build(
    run_upgrade, sandbox_dir, registry, build_stub, recorder, missing_dir
):
    Path(f"{sandbox_dir}/{missing_dir}").rmdir()

    exit_code, out, err = run_upgrade(["sbx1", "--no-cache"])

    assert exit_code == 1
    assert "BUILD RAN" not in out
    assert err == (
        f"sbx-upgrade: missing {sandbox_dir}/{missing_dir}; create it with mkdir -p, "
        f"or fix the path in {registry / 'sbx1.json'}\n"
    )
    assert build_stub.option_list_list == []
    assert recorder.call_list == []


def test_a_broken_entry_is_refused_with_its_own_error_before_the_build(run_upgrade, registry, build_stub, recorder):
    (registry / "sbx1.json").write_text("[]")

    exit_code, _, err = run_upgrade(["sbx1"])

    assert exit_code == 1
    assert err == f"sbx-upgrade: the entry {registry / 'sbx1.json'} is not a JSON object\n"
    assert build_stub.option_list_list == []


def test_a_tag_other_than_local_or_test_is_refused_first(run_upgrade, sandbox_dir, build_stub, recorder):
    exit_code, out, err = run_upgrade(["sbx1"], {"SBX_IMAGE_TAG": "latest"})

    assert exit_code == 1
    assert out == ""
    assert err == "sbx-upgrade: SBX_IMAGE_TAG must be local or test, not 'latest'\n"
    assert build_stub.option_list_list == []
    assert recorder.call_list == []


# ------------------------------------------------------------------------------
# The warning and the build
# ------------------------------------------------------------------------------

def test_a_stopped_sandbox_is_not_warned(run_upgrade, sandbox_dir, build_stub, recorder):
    exit_code, out, _ = run_upgrade(["sbx1"])

    assert exit_code == 0
    assert "will close its open shells" not in out


def test_build_options_after_the_name_reach_the_build_in_order(run_upgrade, sandbox_dir, build_stub, recorder):
    run_upgrade(["sbx1", "--no-cache", "--pull"])

    assert build_stub.option_list_list == [["--no-cache", "--pull"]]
    assert build_stub.repo_dir_list == [REPO_DIR]


def test_no_option_means_an_empty_option_list(run_upgrade, sandbox_dir, build_stub, recorder):
    run_upgrade(["sbx1"])

    assert build_stub.option_list_list == [[]]


def test_a_failed_build_leaves_the_sandbox_alone_and_makes_no_compose_call(run_upgrade, sandbox_dir, recorder):
    failing_stub = BuildStub(recorder, exit_code=1)

    exit_code, out, err = run_upgrade(["sbx1"], stub=failing_stub)

    assert exit_code == 1
    assert err == "sbx-upgrade: the build failed; sbx-sbx1 was left as it was\n"
    assert "sbx-init" not in out
    assert _compose_call_list(recorder) == []
    assert not any(call[0] in ("exec", "stop", "rm") for call in recorder.call_list)


def test_the_default_build_function_is_the_build_module_main():
    parameter = inspect.signature(upgrade_module.main).parameters["build_function"]

    assert parameter.default is build_module.main


# ------------------------------------------------------------------------------
# The recreate and the closing lines
# ------------------------------------------------------------------------------

def test_a_failing_up_after_the_build_names_the_logs(run_upgrade, sandbox_dir, build_stub, recorder):
    recorder.answer(["compose"], DockerResult(1, ""))

    exit_code, out, err = run_upgrade(["sbx1"])

    assert exit_code == 1
    assert err == "sbx-upgrade: docker compose up failed after the build; docker logs sbx-sbx1 shows why\n"
    assert "runs on the new images" not in out


def test_a_failing_tool_versions_read_is_named(run_upgrade, sandbox_dir, build_stub, recorder):
    recorder.answer(VERSIONS_PREFIX, DockerResult(1, ""))

    exit_code, _, err = run_upgrade(["sbx1"])

    assert exit_code == 1
    assert err == "sbx-upgrade: could not read /etc/sbx/tool-versions in sbx-sbx1\n"


def test_upgrade_never_deletes_or_stops_anything(run_upgrade, sandbox_dir, build_stub, recorder, registry):
    run_upgrade(["sbx1"])

    assert (registry / "sbx1.json").is_file()

    for call in recorder.call_list:
        assert call[0] in ("container", "compose", "exec")
        assert "down" not in call
        assert "rm" not in call
