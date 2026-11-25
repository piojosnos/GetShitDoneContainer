# --------------------------------------------------------------------------------
# Scenario: sbx-rm removes the container and keeps every file
# --------------------------------------------------------------------------------
# sbx-rm is the one command that removes a container, so this scenario shows what
# it takes and what it must leave: the directory, the registry entry (unless
# --unregister), the images and every other sandbox. Volumes are not compared:
# no scenario sees a volume, and the one-mount check covers them. The scenario
# deletes no file itself; a directory it moves away goes back by rename in a
# finally block.
# --------------------------------------------------------------------------------

import os
import time
from pathlib import Path

from agent_specs import AgentSpec
from scenario_helpers import (
    container_is_running,
    describe_result,
    docker_exec,
    inspect_container,
    other_sbx_container_map,
    register_sandbox,
    run_sbx,
    run_timeout,
    step,
    throwaway_sandbox,
)

_SESSIONS_WARNING = "will close its open shells and Claude sessions"
_DELETED_ENTRY_TEXT = "deleted the registry entry"


# --------------------------------------------------------------------------------
# What Docker has
# --------------------------------------------------------------------------------

def _network_exists(network: str) -> bool:
    return run_timeout(["docker", "network", "inspect", network], 60).returncode == 0


# --------------------------------------------------------------------------------

def _image_exists(image: str) -> bool:
    return run_timeout(["docker", "image", "inspect", image], 60).returncode == 0


# --------------------------------------------------------------------------------
# What sbx-rm printed and left
# --------------------------------------------------------------------------------

def _closing_line(container: str, sandbox_dir: Path) -> str:
    return f"sbx-rm: the container {container} is gone; nothing in {sandbox_dir} was changed"


# --------------------------------------------------------------------------------

def _last_line(text: str) -> str:
    line_list = text.strip().splitlines()

    if not line_list:
        return ""

    return line_list[-1]


# --------------------------------------------------------------------------------

def _sentinel_problem_list(project_dir: Path, state_dir: Path, sentinel_text: str) -> list[str]:
    problem_list = []
    history_file = state_dir / "shell" / "bash_history"

    for path in [project_dir / "rm-sentinel.txt", state_dir / "rm-sentinel.txt"]:
        if not path.is_file():
            problem_list.append(f"{path} is missing")

            continue

        found_text = path.read_text(encoding="utf-8")

        if found_text != f"{sentinel_text}\n":
            problem_list.append(f"{path} changed: {found_text!r}")

    if not history_file.is_file():
        problem_list.append(f"{history_file} is missing")
    elif sentinel_text not in history_file.read_text(encoding="utf-8", errors="replace").splitlines():
        problem_list.append(f"the sentinel line is missing from {history_file}")

    return problem_list


# --------------------------------------------------------------------------------
# test_rm_removes_the_container_and_keeps_every_file
# --------------------------------------------------------------------------------
# sbx-rm refused without --yes -> --yes removes container and network -> --unregister -> sbx-add brings the files back
# --------------------------------------------------------------------------------

def test_rm_removes_the_container_and_keeps_every_file(
    agent: AgentSpec,
    test_images: None,
    hosttest_env: dict[str, str],
    run_dir: Path,
    sandbox_cleanup: list[str],
):
    sandbox = throwaway_sandbox("rm", agent, run_dir)
    network = f"{sandbox.container}_default"
    closing_line = _closing_line(sandbox.container, sandbox.sandbox_dir)
    sentinel_text = f"rm-{os.getpid()}-{int(time.time())}"
    entry_before = b""
    others_before = {}

    with step("add and start the sandbox"):
        add = register_sandbox(sandbox, hosttest_env, sandbox_cleanup)

        assert add.returncode == 0, f"sbx-add failed: {describe_result(add)}"

        entry_before = sandbox.entry_file.read_bytes()
        start = run_sbx("sbx-start", [sandbox.name], hosttest_env)

        assert start.returncode == 0, f"sbx-start failed: {describe_result(start)}"
        assert container_is_running(sandbox.container), f"{sandbox.container} is not running"

    with step("plant sentinels"):
        (sandbox.project_dir / "rm-sentinel.txt").write_text(f"{sentinel_text}\n", encoding="utf-8")
        (sandbox.state_dir / "rm-sentinel.txt").write_text(f"{sentinel_text}\n", encoding="utf-8")

        history = docker_exec(
            sandbox.container,
            f'mkdir -p "$(dirname "$HISTFILE")" && printf \'%s\\n\' {sentinel_text} >> "$HISTFILE"',
        )
        problem_list = _sentinel_problem_list(sandbox.project_dir, sandbox.state_dir, sentinel_text)

        assert history.returncode == 0, f"the history line was not written: {describe_result(history)}"
        assert not problem_list, "\n".join(problem_list)

    with step("record the other sbx- containers"):
        others_before = other_sbx_container_map(sandbox.container)

    with step("refused without a terminal or --yes"):
        refused = run_sbx("sbx-rm", [sandbox.name, "--unregister"], hosttest_env)

        assert refused.returncode == 1, f"sbx-rm without a terminal or --yes did not exit 1: {describe_result(refused)}"
        assert "--yes" in refused.stderr, f"the refusal does not name --yes: {describe_result(refused)}"
        assert container_is_running(sandbox.container), f"{sandbox.container} is not running after the refusal"
        assert sandbox.entry_file.read_bytes() == entry_before, "the refused sbx-rm changed the entry"

    with step("--yes removes the container and its network"):
        assert _network_exists(network), (
            f"the network {network} does not exist while the sandbox runs; "
            "Compose names its network differently on this host"
        )

        removed = run_sbx("sbx-rm", [sandbox.name, "--yes"], hosttest_env)
        problem_list = _sentinel_problem_list(sandbox.project_dir, sandbox.state_dir, sentinel_text)

        assert removed.returncode == 0, f"sbx-rm --yes failed: {describe_result(removed)}"
        assert _SESSIONS_WARNING in removed.stdout, f"the running sandbox got no warning:\n{removed.stdout}"
        assert inspect_container(sandbox.container) is None, f"{sandbox.container} still exists after sbx-rm"
        assert not _network_exists(network), f"the network {network} still exists after sbx-rm"
        assert sandbox.entry_file.read_bytes() == entry_before, "sbx-rm without --unregister changed the entry"
        assert not problem_list, "\n".join(problem_list)
        assert _image_exists(f"sbx-{agent.name}:test"), f"the image sbx-{agent.name}:test is gone after sbx-rm"
        assert _image_exists("sbx-base:test"), "the image sbx-base:test is gone after sbx-rm"
        assert _last_line(removed.stdout) == closing_line, removed.stdout

    with step("a second sbx-rm with no container succeeds"):
        again = run_sbx("sbx-rm", [sandbox.name], hosttest_env)

        assert again.returncode == 0, f"sbx-rm with no container failed: {describe_result(again)}"
        assert _last_line(again.stdout) == closing_line, again.stdout

    with step("sbx-rm with the directory moved away"):
        start_moved = run_sbx("sbx-start", [sandbox.name], hosttest_env)
        stop_moved = run_sbx("sbx-stop", [sandbox.name], hosttest_env)
        moved_dir = sandbox.sandbox_dir.with_name(f"{sandbox.sandbox_dir.name} moved")

        assert start_moved.returncode == 0, f"sbx-start failed: {describe_result(start_moved)}"
        assert stop_moved.returncode == 0, f"sbx-stop failed: {describe_result(stop_moved)}"
        assert inspect_container(sandbox.container) is not None, f"{sandbox.container} was not made"

        sandbox.sandbox_dir.rename(moved_dir)

        try:
            moved = run_sbx("sbx-rm", [sandbox.name], hosttest_env)
        finally:
            moved_dir.rename(sandbox.sandbox_dir)

        problem_list = _sentinel_problem_list(sandbox.project_dir, sandbox.state_dir, sentinel_text)

        assert moved.returncode == 0, f"sbx-rm with the directory moved away failed: {describe_result(moved)}"
        assert inspect_container(sandbox.container) is None, f"{sandbox.container} still exists after sbx-rm"
        assert not problem_list, "\n".join(problem_list)

    with step("--unregister deletes only the entry"):
        unregistered = run_sbx("sbx-rm", [sandbox.name, "--unregister"], hosttest_env)
        problem_list = _sentinel_problem_list(sandbox.project_dir, sandbox.state_dir, sentinel_text)

        assert unregistered.returncode == 0, f"sbx-rm --unregister failed: {describe_result(unregistered)}"
        assert not sandbox.entry_file.exists(), "the entry still exists after sbx-rm --unregister"
        assert _DELETED_ENTRY_TEXT in unregistered.stdout, unregistered.stdout
        assert sandbox.project_dir.is_dir(), f"{sandbox.project_dir} is gone after sbx-rm --unregister"
        assert sandbox.state_dir.is_dir(), f"{sandbox.state_dir} is gone after sbx-rm --unregister"
        assert not problem_list, "\n".join(problem_list)

    with step("sbx-add of the same directory brings the files back"):
        add_again = register_sandbox(sandbox, hosttest_env, sandbox_cleanup)

        assert add_again.returncode == 0, f"sbx-add of the same directory failed: {describe_result(add_again)}"
        assert sandbox.entry_file.read_bytes() == entry_before, "sbx-add did not write the same entry again"

        start_again = run_sbx("sbx-start", [sandbox.name], hosttest_env)

        assert start_again.returncode == 0, f"sbx-start after sbx-add failed: {describe_result(start_again)}"

        project_read = docker_exec(sandbox.container, f"cat /home/sandbox/workspace/{sandbox.name}/rm-sentinel.txt")
        state_read = docker_exec(sandbox.container, "cat /home/sandbox/workspace/state/rm-sentinel.txt")
        history_read = docker_exec(sandbox.container, f'grep -Fx -- {sentinel_text} "$HISTFILE"')

        assert project_read.stdout.strip() == sentinel_text, (
            f"the project file did not come back in the new container: {describe_result(project_read)}"
        )
        assert state_read.stdout.strip() == sentinel_text, (
            f"the state file did not come back in the new container: {describe_result(state_read)}"
        )
        assert history_read.returncode == 0, (
            f"the history line did not come back in the new container: {describe_result(history_read)}"
        )

    with step("other sandboxes unchanged"):
        others_after = other_sbx_container_map(sandbox.container)

        assert others_after == others_before, f"before: {others_before}\nafter: {others_after}"
