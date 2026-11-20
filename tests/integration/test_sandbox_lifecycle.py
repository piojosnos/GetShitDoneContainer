# ------------------------------------------------------------------------------
# Scenario: add, start and stop a sandbox by name
# ------------------------------------------------------------------------------
# The commands a user types first, run the way a user runs them: found through
# PATH, on a throwaway sandbox whose directory has a space. The ambient
# COMPOSE_PROJECT_NAME of the test environment is a decoy; the commands must
# ignore it and take everything from the registry.
# ------------------------------------------------------------------------------

import json
import os
import shutil
import time
from pathlib import Path

from agent_specs import AgentSpec
from scenario_helpers import (
    REPO_DIR,
    container_id_of,
    container_is_running,
    describe_result,
    docker_exec,
    inspect_container,
    one_bind_mount_problem,
    register_sandbox,
    run_sbx,
    step,
    throwaway_sandbox,
)

_COMMAND_NAME_LIST = [
    "sbx-add",
    "sbx-fix-modes",
    "sbx-list",
    "sbx-migrate-registry",
    "sbx-rm",
    "sbx-shell",
    "sbx-start",
    "sbx-stop",
    "sbx-upgrade",
]
_STOP_SECONDS_LIMIT = 10
_PROJECT_LABEL = "com.docker.compose.project"


# ------------------------------------------------------------------------------
# Checks on the container
# ------------------------------------------------------------------------------

def _labels_and_entrypoint_problem_list(container: str, expected_project: str) -> list[str]:
    inspected = inspect_container(container)

    if inspected is None:
        return [f"{container} is not there"]

    problem_list = []
    config = inspected.get("Config") or {}
    label_map = config.get("Labels") or {}
    project = label_map.get(_PROJECT_LABEL)
    entrypoint = config.get("Entrypoint")

    if project != expected_project:
        problem_list.append(
            f"the Compose project is {project!r}, expected {expected_project!r}; "
            "the ambient COMPOSE_PROJECT_NAME was not ignored"
        )

    if entrypoint:
        problem_list.append(f"{container} has the entrypoint {entrypoint!r}; the image must have none")

    return problem_list


def _unchanged_file_problem_list(expected_map: dict) -> list[str]:
    problem_list = []

    for path, expected_text in expected_map.items():
        if not path.is_file():
            problem_list.append(f"{path} is missing")

            continue

        found_text = path.read_text(encoding="utf-8")

        if found_text != expected_text:
            problem_list.append(f"{path} changed: {found_text!r}, expected {expected_text!r}")

    return problem_list


# ------------------------------------------------------------------------------
# test_add_start_stop_start
# ------------------------------------------------------------------------------
# sbx-add -> sbx-stop before start -> sbx-start -> sbx-stop -> sbx-start reuses the container
# ------------------------------------------------------------------------------

def test_add_start_stop_start(
    agent: AgentSpec,
    test_images: None,
    hosttest_env: dict[str, str],
    run_dir: Path,
    sandbox_cleanup: list[str],
):
    sandbox = throwaway_sandbox("life", agent, run_dir)
    sentinel_text = f"life-{os.getpid()}-{int(time.time())}\n"
    sentinel_map = {
        sandbox.project_dir / "life-sentinel.txt": sentinel_text,
        sandbox.state_dir / "life-sentinel.txt": sentinel_text,
    }
    first_id = ""

    with step("every command is found through PATH"):
        for command in _COMMAND_NAME_LIST:
            found = shutil.which(command, path=hosttest_env["PATH"])

            assert found == str(REPO_DIR / "bin" / command), (
                f"{command} was found as {found!r} through PATH, expected {REPO_DIR / 'bin' / command}"
            )

    with step("sbx-add registers the sandbox"):
        add = register_sandbox(sandbox, hosttest_env, sandbox_cleanup)

        assert add.returncode == 0, f"sbx-add failed: {describe_result(add)}"
        assert sandbox.entry_file.is_file(), f"{sandbox.entry_file} was not written"
        assert json.loads(sandbox.entry_file.read_text(encoding="utf-8")) == {
            "path": str(sandbox.sandbox_dir),
            "agent": agent.name,
        }
        assert sandbox.project_dir.is_dir(), f"{sandbox.project_dir} was not made"
        assert sandbox.state_dir.is_dir(), f"{sandbox.state_dir} was not made"

    with step("a second sbx-add is refused"):
        entry_before = sandbox.entry_file.read_bytes()
        again = run_sbx("sbx-add", [sandbox.name, str(sandbox.sandbox_dir), agent.name], hosttest_env)

        assert again.returncode == 1, f"a second sbx-add did not exit 1: {describe_result(again)}"
        assert "is already registered" in again.stderr, describe_result(again)
        assert sandbox.entry_file.read_bytes() == entry_before, "the second sbx-add changed the entry"

    with step("sbx-stop before any start exits 0"):
        stop_first = run_sbx("sbx-stop", [sandbox.name], hosttest_env)

        assert stop_first.returncode == 0, f"sbx-stop before any start failed: {describe_result(stop_first)}"

    with step("sbx-start runs on the registered directory"):
        for path, text in sentinel_map.items():
            path.write_text(text, encoding="utf-8")

        start = run_sbx("sbx-start", [sandbox.name], hosttest_env)

        assert start.returncode == 0, f"sbx-start failed: {describe_result(start)}"
        assert container_is_running(sandbox.container), f"{sandbox.container} is not running after sbx-start"

        mount_problem = one_bind_mount_problem(sandbox.container, sandbox.sandbox_dir)
        field_problem_list = _labels_and_entrypoint_problem_list(sandbox.container, f"sbx-{sandbox.name}")
        read_back = docker_exec(sandbox.container, f"cat /home/sandbox/workspace/{sandbox.name}/life-sentinel.txt")

        assert mount_problem is None, mount_problem
        assert not field_problem_list, "\n".join(field_problem_list)
        assert read_back.stdout == sentinel_text, (
            f"the container did not read back the file written on the host: {describe_result(read_back)}"
        )

        first_id = container_id_of(sandbox.container)

        assert first_id, f"{sandbox.container} has no id"

    with step("sbx-stop is quick and keeps files"):
        started_at = time.monotonic()
        stop = run_sbx("sbx-stop", [sandbox.name], hosttest_env)
        stop_seconds = time.monotonic() - started_at
        stop_again = run_sbx("sbx-stop", [sandbox.name], hosttest_env)
        problem_list = _unchanged_file_problem_list(sentinel_map)

        assert stop.returncode == 0, f"sbx-stop failed: {describe_result(stop)}"
        assert stop_seconds < _STOP_SECONDS_LIMIT, (
            f"sbx-stop took {stop_seconds:.1f} s; {_STOP_SECONDS_LIMIT} s or more means the stop fell through to a kill"
        )
        assert not container_is_running(sandbox.container), f"{sandbox.container} still runs after sbx-stop"
        assert not problem_list, "\n".join(problem_list)
        assert stop_again.returncode == 0, f"a second sbx-stop failed: {describe_result(stop_again)}"

    with step("the next sbx-start reuses the container"):
        start_again = run_sbx("sbx-start", [sandbox.name], hosttest_env)

        assert start_again.returncode == 0, f"the second sbx-start failed: {describe_result(start_again)}"
        assert container_is_running(sandbox.container), f"{sandbox.container} is not running after the second start"
        assert container_id_of(sandbox.container) == first_id, "the second sbx-start did not reuse the container"

    with step("sbx-start of a running sandbox is silent"):
        start_running = run_sbx("sbx-start", [sandbox.name], hosttest_env)
        output = start_running.stdout + start_running.stderr

        assert start_running.returncode == 0, f"sbx-start of a running sandbox failed: {describe_result(start_running)}"
        assert "older image" not in output, (
            f"sbx-start warned about an older image for a sandbox on the current image:\n{output}"
        )
        assert container_id_of(sandbox.container) == first_id, "sbx-start of a running sandbox recreated the container"
