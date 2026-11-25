# --------------------------------------------------------------------------------
# Scenario: sbx-init gives root-owned state back to the sandbox user
# --------------------------------------------------------------------------------
# The sandbox cannot change owners itself, so a root-owned file in state/ (left by
# a root container) would break the agent's next write. One named throwaway root
# container, offline and removed in a finally block, plants such a file on the test
# sandbox's mount; sbx-init must hand it back. The planted file is removed again by
# a finalizer, whatever happened.
# --------------------------------------------------------------------------------

import os

import pytest

from sbx.names import base_image
from scenario_helpers import RunSandbox, describe_result, docker_exec, run_timeout, step

_WORKSPACE = "/home/sandbox/workspace"
_TEST_TAG = "test"
_SANDBOX_UID = "1000"
_ROOT_UID = "0"
_SKIPPED_STATE_PATH_LIST = ["*/state/cache/npm*", "*/state/cache/uv*", "*/state/m2*"]


# --------------------------------------------------------------------------------
# Reading the owner and finding root-owned state
# --------------------------------------------------------------------------------

def _owner_of(container: str, path: str) -> str:
    return docker_exec(container, f"stat -c %u {path}").stdout.strip()


# --------------------------------------------------------------------------------

def _root_owned_command() -> str:
    command = f"find {_WORKSPACE}/state -user 0"

    for skipped_path in _SKIPPED_STATE_PATH_LIST:
        command += f" -not -path '{skipped_path}'"

    return command


# --------------------------------------------------------------------------------
# test_init_gives_root_owned_state_back
# --------------------------------------------------------------------------------
# root container plants a root-owned file in state -> sbx-init -> owned by sandbox,
# nothing root-owned left
# --------------------------------------------------------------------------------

def test_init_gives_root_owned_state_back(sandbox: RunSandbox, request: pytest.FixtureRequest):
    agent = sandbox.agent
    container = sandbox.container
    planted_file = f"{_WORKSPACE}/state/{agent.config_dir_name}/owner-fix-root-owned-{os.getpid()}"
    plant_container = f"sbx-hosttest-ownerfix-{agent.name}"

    def remove_planted_file() -> None:
        docker_exec(container, f"rm -f {planted_file}")

    request.addfinalizer(remove_planted_file)

    with step("plant a root-owned file"):
        try:
            plant = run_timeout(
                [
                    "docker", "run", "--rm", "--name", plant_container, "--network", "none",
                    "-u", "root", "--volumes-from", container, "--entrypoint", "sh",
                    base_image(_TEST_TAG), "-c", f"touch {planted_file}",
                ],
                120,
            )
        finally:
            run_timeout(["docker", "rm", "-f", plant_container], 60)

        assert plant.returncode == 0, f"the root container could not make {planted_file}: {describe_result(plant)}"
        assert _owner_of(container, planted_file) == _ROOT_UID, (
            f"the plant did not take: {planted_file} is owned by {_owner_of(container, planted_file)!r}, not {_ROOT_UID}"
        )

    with step("sbx-init gives it back"):
        init = docker_exec(container, "sbx-init", 600)
        expected_line = f"sbx-init: {agent.init_step_count} steps passed; run sbx-selfcheck to check the sandbox"
        output_line_list = init.stdout.strip().splitlines()

        assert init.returncode == 0, f"sbx-init failed: {describe_result(init)}"
        assert output_line_list and output_line_list[-1] == expected_line, describe_result(init)
        assert _owner_of(container, planted_file) == _SANDBOX_UID, (
            f"{planted_file} is owned by {_owner_of(container, planted_file)!r} after sbx-init, expected {_SANDBOX_UID}"
        )

    with step("nothing under state is owned by root"):
        found = docker_exec(container, _root_owned_command())

        assert found.returncode == 0, f"the search for root-owned state failed: {describe_result(found)}"
        assert not found.stdout.strip(), f"paths under state/ are still owned by root after sbx-init:\n{found.stdout.strip()}"
