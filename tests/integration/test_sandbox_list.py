# ------------------------------------------------------------------------------
# Scenario: sbx-list shows each sandbox with the status docker ps -a shows
# ------------------------------------------------------------------------------
# Rows are compared as the exact text sbx-list prints, so a wrong column width, a
# stale status or a false older-image mark fails. Only the lines of the test
# sandboxes are read: the host also runs your own sandboxes, which this scenario
# never touches; the test registry holds the test sandboxes only.
# ------------------------------------------------------------------------------

from pathlib import Path

from agent_specs import AgentSpec
from scenario_helpers import (
    RunSandbox,
    describe_result,
    register_sandbox,
    run_sbx,
    run_timeout,
    step,
    throwaway_sandbox,
)

_NO_SANDBOXES_LINE = "sbx-list: no sandboxes registered; register one with: sbx-add NAME HOST_PATH"


# ------------------------------------------------------------------------------
# The text sbx-list prints
# ------------------------------------------------------------------------------
# Written out here and not imported, so the scenario is an independent reading of
# the format: the name in 31 columns, the status in 20, then the directory; and a
# container without a registry entry indented by two, in 35 columns.
# ------------------------------------------------------------------------------

def _row(name: str, status: str, path: Path) -> str:
    return f"{name:<31} {status:<20} {path}"


def _leftover_line(container: str, status: str) -> str:
    return f"  {container:<35} {status}"


# ------------------------------------------------------------------------------
# What docker ps -a says
# ------------------------------------------------------------------------------
# The empty text means Docker has no such container. A failed docker ps is a
# failure of its own, never read as no container.
# ------------------------------------------------------------------------------

def _docker_state(container: str) -> str:
    listing = run_timeout(["docker", "ps", "-a", "--format", "{{.Names}} {{.State}}"], 60)

    assert listing.returncode == 0, f"docker ps -a failed: {describe_result(listing)}"

    for line in listing.stdout.splitlines():
        name, _, state = line.partition(" ")

        if name == container:
            return state

    return ""


def _list_lines(environ: dict[str, str]) -> list[str]:
    listing = run_sbx("sbx-list", [], environ)

    assert listing.returncode == 0, f"sbx-list failed: {describe_result(listing)}"

    return listing.stdout.splitlines()


def _row_problem(line_list: list[str], sandbox: RunSandbox, status: str, expected_docker_state: str) -> str | None:
    row = _row(sandbox.name, status, sandbox.sandbox_dir)
    docker_state = _docker_state(sandbox.container)

    if row not in line_list:
        return (
            f"sbx-list did not print the row {row!r}; docker ps -a shows {docker_state or 'no container'}\n"
            + "\n".join(line_list)
        )

    if docker_state != expected_docker_state:
        return (
            f"docker ps -a shows {docker_state or 'no container'} for {sandbox.container}, "
            f"expected {expected_docker_state or 'no container'}"
        )

    return None


# ------------------------------------------------------------------------------
# test_list_shows_the_docker_state
# ------------------------------------------------------------------------------
# empty registry -> add -> start -> stop: each row matches docker ps -a
# ------------------------------------------------------------------------------

def test_list_shows_the_docker_state(
    agent: AgentSpec,
    test_images: None,
    hosttest_env: dict[str, str],
    run_dir: Path,
    sandbox_cleanup: list[str],
    sandbox: RunSandbox,
):
    throwaway = throwaway_sandbox("list", agent, run_dir)

    with step("an empty registry"):
        empty_config = run_dir / f"cfg-empty-{agent.name}"
        empty_config.mkdir()
        empty_environ = dict(hosttest_env)
        empty_environ["SBX_CONFIG_DIR"] = str(empty_config)
        line_list = _list_lines(empty_environ)

        assert _NO_SANDBOXES_LINE in line_list, "\n".join(line_list)
        assert _leftover_line(sandbox.container, "running") in line_list, (
            f"the running {sandbox.container} is not listed as a container without a registry entry\n"
            + "\n".join(line_list)
        )

        for line in line_list:
            assert "cc_" not in line, f"an old-layout container is listed: {line}"

        assert _docker_state(sandbox.container) == "running"

    with step("registered, no container"):
        add = register_sandbox(throwaway, hosttest_env, sandbox_cleanup)

        assert add.returncode == 0, f"sbx-add failed: {describe_result(add)}"

        problem = _row_problem(_list_lines(hosttest_env), throwaway, "no container", "")

        assert problem is None, problem

    with step("running"):
        start = run_sbx("sbx-start", [throwaway.name], hosttest_env)

        assert start.returncode == 0, f"sbx-start failed: {describe_result(start)}"

        line_list = _list_lines(hosttest_env)
        problem = _row_problem(line_list, throwaway, "running", "running")

        assert problem is None, problem
        assert _leftover_line(throwaway.container, "running") not in line_list, (
            f"{throwaway.container} is listed as having no registry entry, although it is registered"
        )

    with step("stopped"):
        stop = run_sbx("sbx-stop", [throwaway.name], hosttest_env)

        assert stop.returncode == 0, f"sbx-stop failed: {describe_result(stop)}"

        problem = _row_problem(_list_lines(hosttest_env), throwaway, "stopped", "exited")

        assert problem is None, problem
