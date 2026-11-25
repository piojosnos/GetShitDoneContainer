# --------------------------------------------------------------------------------
# Scenario: git works in the container on a repository made on the host
# --------------------------------------------------------------------------------
# The project directory is the user's own, owned by the host user, so git inside
# the container must not refuse it as a directory of another owner. The host git
# call ignores your own git configuration, and the repository the scenario makes
# is removed again when it ends.
# --------------------------------------------------------------------------------

import os
import shutil

import pytest

from scenario_helpers import RunSandbox, describe_result, docker_exec, run_timeout, step

_REPO_DIR_NAME = "host-repo"
_WORKSPACE_DIR = "/home/sandbox/workspace"
_GIT_SECONDS = 60


# --------------------------------------------------------------------------------
# test_git_works_on_a_repo_made_on_the_host
# --------------------------------------------------------------------------------
# git init on the host -> git status in the container -> no dubious ownership
# --------------------------------------------------------------------------------

def test_git_works_on_a_repo_made_on_the_host(sandbox: RunSandbox, request: pytest.FixtureRequest):
    repo_dir = sandbox.project_dir / _REPO_DIR_NAME

    with step("git init on the host"):
        environ = dict(os.environ)
        environ["GIT_CONFIG_GLOBAL"] = "/dev/null"
        environ["GIT_CONFIG_NOSYSTEM"] = "1"

        def remove_repo() -> None:
            shutil.rmtree(repo_dir, ignore_errors=True)

        repo_dir.mkdir()
        request.addfinalizer(remove_repo)

        init = run_timeout(["git", "init", "-q", str(repo_dir)], _GIT_SECONDS, environ)

        assert init.returncode == 0, f"git init of {repo_dir} on the host failed: {describe_result(init)}"

    with step("git status in the container"):
        container_repo = f"{_WORKSPACE_DIR}/{sandbox.name}/{_REPO_DIR_NAME}"
        status = docker_exec(sandbox.container, f"git -C {container_repo} status")
        output = status.stdout + status.stderr

        assert status.returncode == 0, f"git status in the container failed: {describe_result(status)}"
        assert "dubious ownership" not in output, f"git refused the repository as one of another owner:\n{output}"
