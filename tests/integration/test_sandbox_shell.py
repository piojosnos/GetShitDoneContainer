# --------------------------------------------------------------------------------
# Scenario: sbx-shell starts the sandbox if needed and opens bash in its directory
# --------------------------------------------------------------------------------
# The shell needs a terminal, so a scenario drives it through a pseudo-terminal
# made with the pty module. The exit status of the shell must reach the caller
# through the uv process that runs sbx-shell, so the script a shell runs ends with
# a status that is not 0.
# --------------------------------------------------------------------------------

import os
import pty
import select
import shutil
import signal
import subprocess
import time
from pathlib import Path

from agent_specs import AgentSpec
from scenario_helpers import (
    CommandResult,
    REPO_DIR,
    container_id_of,
    container_is_running,
    describe_result,
    inspect_container,
    register_sandbox,
    run_sbx,
    run_timeout,
    step,
    throwaway_sandbox,
)

_WORKSPACE_DIR = "/home/sandbox/workspace"
_SHELL_SECONDS = 300
_READ_SECONDS = 0.5
_PROBE_INTERVAL_SECONDS = 1.0
_PROBE_SECONDS = 30
_READ_SIZE = 4096
_NO_TERMINAL_TEXT_LIST = ["not a tty", "not a terminal"]


# --------------------------------------------------------------------------------
# Driving sbx-shell through a pseudo-terminal
# --------------------------------------------------------------------------------
# The script text is written only when a bash runs in the container: input that
# arrives before Docker has put the terminal in raw mode may be lost on some
# systems. sbx-shell starts in its own session; when the shell does not end within
# the time, the whole group is killed, and the closed terminal ends the shell in
# the container. The terminal output is kept for the failure message.
# --------------------------------------------------------------------------------

def _bash_is_running(container: str) -> bool:
    probe = run_timeout(["docker", "exec", container, "pgrep", "-x", "bash"], _PROBE_SECONDS)

    return probe.returncode == 0


def _read_available(master_fd: int) -> bytes | None:
    readable_list, _, _ = select.select([master_fd], [], [], _READ_SECONDS)

    if not readable_list:
        return b""

    try:
        data = os.read(master_fd, _READ_SIZE)
    except OSError:
        return None

    if not data:
        return None

    return data


def _kill_group(process: subprocess.Popen) -> None:
    try:
        os.killpg(process.pid, signal.SIGKILL)
    except ProcessLookupError:
        return

    process.wait()


def _shell_through_pty(name: str, environ: dict[str, str], script_text: str, seconds: float) -> CommandResult:
    container = f"sbx-{name}"
    master_fd, slave_fd = pty.openpty()
    chunk_list = []
    sent = False
    end_of_output = False
    next_probe = 0.0

    try:
        process = subprocess.Popen(
            ["sbx-shell", name],
            env=environ,
            stdin=slave_fd,
            stdout=slave_fd,
            stderr=slave_fd,
            start_new_session=True,
        )
    finally:
        os.close(slave_fd)

    deadline = time.monotonic() + seconds

    try:
        while process.poll() is None and time.monotonic() < deadline:
            if not sent and time.monotonic() >= next_probe:
                if _bash_is_running(container):
                    os.write(master_fd, script_text.encode("utf-8"))
                    sent = True

                next_probe = time.monotonic() + _PROBE_INTERVAL_SECONDS

            if end_of_output:
                time.sleep(_READ_SECONDS)

                continue

            data = _read_available(master_fd)

            if data is None:
                end_of_output = True
            elif data:
                chunk_list.append(data)

        timed_out = process.poll() is None

        if timed_out:
            _kill_group(process)
    finally:
        os.close(master_fd)

    transcript = b"".join(chunk_list).decode("utf-8", errors="replace")

    return CommandResult(process.returncode, transcript, "", timed_out)


def _wrote_directory(project_dir: Path, file_name: str, expected_text: str) -> bool:
    path = project_dir / file_name

    return path.is_file() and path.read_text(encoding="utf-8").strip() == expected_text


# --------------------------------------------------------------------------------
# test_shell_opens_bash_in_the_project_dir
# --------------------------------------------------------------------------------
# no container: sbx-shell starts it -> pty shell on running and on stopped sandbox -> bash in the project dir, same container
# --------------------------------------------------------------------------------

def test_shell_opens_bash_in_the_project_dir(
    agent: AgentSpec,
    test_images: None,
    hosttest_env: dict[str, str],
    run_dir: Path,
    sandbox_cleanup: list[str],
):
    sandbox = throwaway_sandbox("shell", agent, run_dir)
    project_path = f"{_WORKSPACE_DIR}/{sandbox.name}"
    first_id = ""
    first_start = ""

    with step("sbx-shell is found through PATH"):
        found = shutil.which("sbx-shell", path=hosttest_env["PATH"])

        assert found == str(REPO_DIR / "bin" / "sbx-shell"), f"sbx-shell was found as {found!r} through PATH"

    with step("add the sandbox"):
        add = register_sandbox(sandbox, hosttest_env, sandbox_cleanup)

        assert add.returncode == 0, f"sbx-add failed: {describe_result(add)}"

    with step("no terminal: Docker refuses after starting the sandbox"):
        no_terminal = run_sbx("sbx-shell", [sandbox.name], hosttest_env)
        output = (no_terminal.stdout + no_terminal.stderr).lower()
        refusal_found = False

        for text in _NO_TERMINAL_TEXT_LIST:
            if text in output:
                refusal_found = True

        assert no_terminal.returncode != 0, f"sbx-shell without a terminal exited 0: {describe_result(no_terminal)}"
        assert refusal_found, f"Docker printed no terminal refusal: {describe_result(no_terminal)}"
        assert container_is_running(sandbox.container), f"{sandbox.container} is not running after sbx-shell"

        first_id = container_id_of(sandbox.container)
        inspected = inspect_container(sandbox.container)
        first_start = inspected["State"]["StartedAt"] if inspected else ""

        assert first_id, f"{sandbox.container} has no id"

    with step("a running sandbox: bash in the project dir"):
        shell = _shell_through_pty(
            sandbox.name,
            hosttest_env,
            f"pwd > {project_path}/shell-running.txt; exit 3\n",
            _SHELL_SECONDS,
        )
        inspected = inspect_container(sandbox.container)
        started_at = inspected["State"]["StartedAt"] if inspected else ""

        assert not shell.timed_out, f"the shell did not end in {_SHELL_SECONDS} s:\n{shell.stdout}"
        assert _wrote_directory(sandbox.project_dir, "shell-running.txt", project_path), (
            f"the shell did not write {project_path} to shell-running.txt:\n{shell.stdout}"
        )
        assert shell.returncode == 3, (
            f"the exit status of the shell did not reach the caller through uv: {shell.returncode}\n{shell.stdout}"
        )
        assert container_id_of(sandbox.container) == first_id, "sbx-shell replaced the running sandbox"
        assert started_at == first_start, "sbx-shell restarted the running sandbox"

    with step("a stopped sandbox: started again, not replaced"):
        stop = run_sbx("sbx-stop", [sandbox.name], hosttest_env)

        assert stop.returncode == 0, f"sbx-stop failed: {describe_result(stop)}"
        assert not container_is_running(sandbox.container), f"{sandbox.container} still runs after sbx-stop"

        shell = _shell_through_pty(
            sandbox.name,
            hosttest_env,
            f"pwd > {project_path}/shell-stopped.txt; exit 0\n",
            _SHELL_SECONDS,
        )

        assert not shell.timed_out, f"the shell did not end in {_SHELL_SECONDS} s:\n{shell.stdout}"
        assert _wrote_directory(sandbox.project_dir, "shell-stopped.txt", project_path), (
            f"the shell did not write {project_path} to shell-stopped.txt:\n{shell.stdout}"
        )
        assert shell.returncode == 0, f"the shell exited {shell.returncode}:\n{shell.stdout}"
        assert container_is_running(sandbox.container), f"{sandbox.container} is not running after the shell"
        assert container_id_of(sandbox.container) == first_id, (
            "sbx-shell of a stopped sandbox replaced the container instead of starting it again"
        )
