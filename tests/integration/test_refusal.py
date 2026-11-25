# --------------------------------------------------------------------------------
# Scenarios: plain docker compose, run by a caller who bypasses the sbx- commands
# --------------------------------------------------------------------------------
# The name rule and the directory check of the commands are unit tested; these
# two prove the guards in compose.yml itself. The environment holds only the
# caller's PATH, HOME and Docker variables plus the four SBX_ values, so nothing
# of the test environment helps the attempt. Whatever the attempt made (a
# container or a network) is removed again when the scenario ends.
# --------------------------------------------------------------------------------

import os
import re
import shutil
from pathlib import Path

import pytest

from agent_specs import AgentSpec
from scenario_helpers import REPO_DIR, CommandResult, run_timeout, step

_UP_SECONDS = 120
_MISSING_DIR_PATTERN = re.compile(r"does not exist|no such file|bind source", re.IGNORECASE)
_PASSED_THROUGH_NAME_LIST = ["PATH", "HOME"]


# --------------------------------------------------------------------------------
# The attempt
# --------------------------------------------------------------------------------

def _caller_environ(sbx_name: str, sbx_dir: Path, agent_name: str) -> dict[str, str]:
    environ = {}

    for key, value in os.environ.items():
        if key in _PASSED_THROUGH_NAME_LIST or key.startswith("DOCKER_"):
            environ[key] = value

    environ["SBX_NAME"] = sbx_name
    environ["SBX_DIR"] = str(sbx_dir)
    environ["SBX_AGENT"] = agent_name
    environ["SBX_IMAGE_TAG"] = "test"

    return environ


def _project_name(agent_name: str) -> str:
    return f"sbx-hosttest-refusal-{agent_name}"


def _container_name_list() -> list[str]:
    listing = run_timeout(["docker", "ps", "-a", "--format", "{{.Names}}"], 60)

    return listing.stdout.split()


def _remove_attempt(container: str, project: str) -> None:
    run_timeout(["docker", "rm", "-f", container], 120)
    run_timeout(["docker", "network", "rm", f"{project}_default"], 60)


def _compose_up(project: str, environ: dict[str, str]) -> CommandResult:
    return run_timeout(
        [
            "docker", "compose", "--env-file", "/dev/null", "-p", project,
            "-f", str(REPO_DIR / "compose.yml"), "up", "-d",
        ],
        _UP_SECONDS,
        environ,
    )


# --------------------------------------------------------------------------------
# test_missing_sandbox_directory_is_refused
# --------------------------------------------------------------------------------
# compose up on a directory that does not exist -> refused, nothing created
# --------------------------------------------------------------------------------

def test_missing_sandbox_directory_is_refused(
    agent: AgentSpec,
    test_images: None,
    run_dir: Path,
    request: pytest.FixtureRequest,
):
    sbx_name = f"hosttest-refusal-{agent.name}"
    container = f"sbx-{sbx_name}"
    project = _project_name(agent.name)
    missing_dir = run_dir / f"does-not-exist-{agent.name}"
    environ = _caller_environ(sbx_name, missing_dir, agent.name)

    def remove_attempt() -> None:
        _remove_attempt(container, project)

    request.addfinalizer(remove_attempt)

    with step("compose up is refused"):
        up = _compose_up(project, environ)
        output = f"{up.stdout}\n{up.stderr}"

        assert not up.timed_out, f"docker compose up timed out\n{output}"
        assert up.returncode != 0, f"compose started a sandbox on a missing directory\n{output}"
        assert _MISSING_DIR_PATTERN.search(output), f"the refusal does not name the missing directory\n{output}"

    with step("nothing was created"):
        assert not missing_dir.exists(), f"Docker created {missing_dir}; create_host_path is not honored"
        assert container not in _container_name_list(), f"the refused attempt made the container {container}"


# --------------------------------------------------------------------------------
# test_uppercase_name_is_refused
# --------------------------------------------------------------------------------
# compose up with an uppercase SBX_NAME -> refused before any container
# --------------------------------------------------------------------------------

def test_uppercase_name_is_refused(
    agent: AgentSpec,
    test_images: None,
    run_dir: Path,
    request: pytest.FixtureRequest,
):
    sbx_name = f"HostTest-{agent.name}"
    container = f"sbx-{sbx_name}"
    project = _project_name(agent.name)
    sbx_dir = run_dir / f"uppercase-name-{agent.name}"
    environ = _caller_environ(sbx_name, sbx_dir, agent.name)

    sbx_dir.mkdir()

    def remove_attempt() -> None:
        _remove_attempt(container, project)
        shutil.rmtree(sbx_dir, ignore_errors=True)

    request.addfinalizer(remove_attempt)

    with step("compose up is refused"):
        up = _compose_up(project, environ)
        output = f"{up.stdout}\n{up.stderr}"

        assert not up.timed_out, f"docker compose up timed out\n{output}"
        assert up.returncode != 0, f"compose accepted an uppercase SBX_NAME\n{output}"
        assert "must be lowercase" in output, f"the refusal is not the name check\n{output}"

    with step("no container was made"):
        assert container not in _container_name_list(), f"the refused attempt made the container {container}"
