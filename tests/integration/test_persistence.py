# ------------------------------------------------------------------------------
# Scenario: a rebuild keeps everything the agent and the user put in a sandbox
# ------------------------------------------------------------------------------
# The core promise of the project: sbx-upgrade recreates the container on new
# images and loses no login, setting, history, cache or file. Every planted file
# holds a run-unique text and is removed again when the scenario ends; no real
# credential is ever written and no agent prompt is run.
# ------------------------------------------------------------------------------

import os
import subprocess
import time
from pathlib import Path

import pytest

from scenario_helpers import (
    RunSandbox,
    docker_exec,
    inspect_container,
    one_bind_mount_problem,
    other_sbx_container_map,
    run_sbx,
    run_timeout,
    step,
)

_HISTORY_WAIT_SECONDS = 10
_UPGRADE_SECONDS = 1800
_OPEN_SHELLS_WARNING = "will close its open shells"
_CACHE_MARKER_FILE = "persist-cache-marker.txt"
_CACHE_LOCATION_LIST = [
    ("npm", "npm config get cache", "/home/sandbox/workspace/state/cache/npm", "cache/npm"),
    ("uv", "uv cache dir", "/home/sandbox/workspace/state/cache/uv", "cache/uv"),
    ("Maven", 'readlink "$HOME/.m2"', "/home/sandbox/workspace/state/m2", "m2"),
]


# ------------------------------------------------------------------------------
# Planting and removing files on the host
# ------------------------------------------------------------------------------
# The finalizer is registered before the file is written, so a failure half way
# leaves nothing behind. A directory the plant had to make is removed again when
# it is empty.
# ------------------------------------------------------------------------------

def _missing_parent_list(path: Path) -> list[Path]:
    missing_list = []
    parent = path.parent

    while not parent.exists():
        missing_list.append(parent)
        parent = parent.parent

    return missing_list


def _plant_file(path: Path, text: str, request: pytest.FixtureRequest) -> None:
    missing_list = _missing_parent_list(path)

    def remove_planted_file() -> None:
        path.unlink(missing_ok=True)

        for missing_dir in missing_list:
            try:
                missing_dir.rmdir()
            except OSError:
                continue

    request.addfinalizer(remove_planted_file)
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(text, encoding="utf-8")


def _remove_on_finalize(path: Path, request: pytest.FixtureRequest) -> None:
    def remove_file() -> None:
        path.unlink(missing_ok=True)

    request.addfinalizer(remove_file)


# ------------------------------------------------------------------------------
# The history marker
# ------------------------------------------------------------------------------
# A shell is held open while the marker is written: the history must reach the
# file per command, because the stop that follows kills the shell without letting
# it write on exit.
# ------------------------------------------------------------------------------

def _remove_history_marker(history_file: Path, marker: str) -> None:
    if not history_file.is_file():
        return

    text = history_file.read_text(encoding="utf-8", errors="surrogateescape")
    kept_list = []

    for line in text.splitlines(keepends=True):
        if marker not in line:
            kept_list.append(line)

    history_file.write_text("".join(kept_list), encoding="utf-8", errors="surrogateescape")


def _history_has(history_file: Path, marker: str) -> bool:
    if not history_file.is_file():
        return False

    return marker in history_file.read_text(encoding="utf-8", errors="surrogateescape")


def _write_history_marker(
    container: str,
    history_file: Path,
    marker: str,
    request: pytest.FixtureRequest,
) -> None:
    shell = subprocess.Popen(
        ["docker", "exec", "-i", container, "bash", "-i"],
        stdin=subprocess.PIPE,
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
        text=True,
        start_new_session=True,
    )

    def close_shell() -> None:
        try:
            shell.stdin.close()
        except OSError:
            pass

        shell.terminate()

        try:
            shell.wait(timeout=10)
        except subprocess.TimeoutExpired:
            shell.kill()
            shell.wait()

    def remove_marker() -> None:
        _remove_history_marker(history_file, marker)

    request.addfinalizer(remove_marker)
    request.addfinalizer(close_shell)

    shell.stdin.write(f"echo {marker}\n")
    shell.stdin.flush()

    deadline = time.monotonic() + _HISTORY_WAIT_SECONDS

    while time.monotonic() < deadline:
        if _history_has(history_file, marker):
            return

        time.sleep(0.5)

    pytest.fail(f"the marker did not reach {history_file} within {_HISTORY_WAIT_SECONDS} s of an open shell")


# ------------------------------------------------------------------------------
# Checks on the sandbox
# ------------------------------------------------------------------------------

def _cache_location_problem_list(container: str) -> list[str]:
    problem_list = []

    for tool, command, expected, _ in _CACHE_LOCATION_LIST:
        result = docker_exec(container, command)
        found = result.stdout.strip()

        if found != expected:
            problem_list.append(f"{tool} keeps its cache in {found!r}, not in {expected}; stderr: {result.stderr.strip()}")

    return problem_list


def _changed_file_list(planted_map: dict[Path, str]) -> list[str]:
    problem_list = []

    for path, expected_text in planted_map.items():
        if not path.is_file():
            problem_list.append(f"{path} is missing")

            continue

        found_text = path.read_text(encoding="utf-8", errors="replace")

        if found_text != expected_text:
            problem_list.append(f"{path} changed: {found_text!r}, expected {expected_text!r}")

    return problem_list


def _last_lines(text: str, count: int) -> list[str]:
    line_list = text.strip().splitlines()

    return line_list[-count:]


# ------------------------------------------------------------------------------
# test_planted_files_survive_one_upgrade
# ------------------------------------------------------------------------------
# plant project, state, clone, history, caches, fake login -> sbx-stop -> sbx-upgrade -> every file still there
# ------------------------------------------------------------------------------

def test_planted_files_survive_one_upgrade(
    sandbox: RunSandbox,
    hosttest_env: dict[str, str],
    request: pytest.FixtureRequest,
):
    agent = sandbox.agent
    plant_text = f"persist-{os.getpid()}-{int(time.time())}"
    history_marker = f"history-{plant_text}"
    history_file = sandbox.state_dir / "shell" / "bash_history"
    planted_map: dict[Path, str] = {}

    with step("plant files on the host"):
        file_text = f"{plant_text}\n"
        login_text = '{"fake": "' + plant_text + '"}\n'
        file_list = [
            sandbox.project_dir / "persist-sentinel.txt",
            sandbox.state_dir / "persist-sentinel.txt",
            sandbox.sandbox_dir / "best-practices" / "persist-sentinel.txt",
        ]

        for path in file_list:
            _plant_file(path, file_text, request)
            planted_map[path] = file_text

        login_file = sandbox.state_dir / agent.config_dir_name / agent.login_file

        _plant_file(login_file, login_text, request)
        planted_map[login_file] = login_text

        if agent.session_dir is not None:
            session_dir = sandbox.state_dir / agent.config_dir_name / agent.session_dir.format(name=sandbox.name)
            session_file = session_dir / "persist-session.jsonl"
            memory_file = session_dir / "memory" / "persist-memory.md"

            _plant_file(session_file, login_text, request)
            planted_map[session_file] = login_text
            _plant_file(memory_file, file_text, request)
            planted_map[memory_file] = file_text

    with step("write a history marker"):
        _write_history_marker(sandbox.container, history_file, history_marker, request)

    with step("caches live in state"):
        problem_list = _cache_location_problem_list(sandbox.container)

        assert not problem_list, "\n".join(problem_list)

        cache_file_list = []

        for _, _, _, state_subdir in _CACHE_LOCATION_LIST:
            cache_file = sandbox.state_dir / state_subdir / _CACHE_MARKER_FILE
            _remove_on_finalize(cache_file, request)
            cache_file_list.append(cache_file)
            planted_map[cache_file] = file_text

        plant = docker_exec(
            sandbox.container,
            'for cacheDir in "$NPM_CONFIG_CACHE" "$UV_CACHE_DIR" "$HOME/.m2"; do '
            f"printf '%s\\n' {plant_text} > \"$cacheDir/{_CACHE_MARKER_FILE}\"; done",
        )

        assert plant.returncode == 0, plant.stderr

        for cache_file in cache_file_list:
            assert cache_file.is_file(), f"{cache_file} was not written on the host"

    with step("record the other sbx- containers"):
        others_before = other_sbx_container_map(sandbox.container)
        before = inspect_container(sandbox.container)

        assert before is not None, f"{sandbox.container} is not there"

        id_before = before["Id"]

    with step("stop the sandbox"):
        stop = run_sbx("sbx-stop", [sandbox.name], hosttest_env)
        stopped = inspect_container(sandbox.container)

        assert stop.returncode == 0, f"sbx-stop exited {stop.returncode}\n{stop.stdout}\n{stop.stderr}"
        assert stopped is not None and stopped["State"]["Running"] is False, f"{sandbox.container} still runs"

    with step("upgrade the stopped sandbox"):
        upgrade = run_sbx("sbx-upgrade", [sandbox.name], hosttest_env, _UPGRADE_SECONDS)
        after = inspect_container(sandbox.container)
        versions = docker_exec(sandbox.container, "cat /etc/sbx/tool-versions")
        last_list = _last_lines(upgrade.stdout, 2)

        assert upgrade.returncode == 0, f"sbx-upgrade exited {upgrade.returncode}\n{upgrade.stdout}\n{upgrade.stderr}"
        assert _OPEN_SHELLS_WARNING not in upgrade.stdout, upgrade.stdout
        assert after is not None, f"{sandbox.container} is not there after sbx-upgrade"
        assert after["Id"] != id_before, "sbx-upgrade did not recreate the container"
        assert after["State"]["Running"] is True, f"{sandbox.container} is not running after sbx-upgrade"
        assert versions.returncode == 0, versions.stderr
        assert len(last_list) == 2, upgrade.stdout
        assert last_list[0] == f"sbx-upgrade: {sandbox.container} runs on the new images", upgrade.stdout
        assert last_list[1] == versions.stdout.strip(), upgrade.stdout

    with step("the planted files survive"):
        problem_list = _changed_file_list(planted_map)

        assert not problem_list, "\n".join(problem_list)

    with step("the history survives"):
        fresh = run_timeout(["docker", "exec", "-i", sandbox.container, "bash", "-i"], 60, stdin="history\nexit\n")

        assert history_marker in fresh.stdout, (
            f"the marker is not in the history of a fresh shell; "
            f"the file on the host has it: {_history_has(history_file, history_marker)}\n{fresh.stdout[:500]}"
        )

    with step("one bind mount"):
        problem = one_bind_mount_problem(sandbox.container, sandbox.sandbox_dir)

        assert problem is None, problem

    with step("other sandboxes unchanged"):
        others_after = other_sbx_container_map(sandbox.container)

        assert others_after == others_before, f"before: {others_before}\nafter: {others_after}"
