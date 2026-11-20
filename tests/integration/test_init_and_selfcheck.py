# ------------------------------------------------------------------------------
# Scenario: sbx-init and sbx-selfcheck pass in a test sandbox of each agent
# ------------------------------------------------------------------------------
# A fresh sandbox correctly fails the git identity and login checks, so the
# scenario plants a fake identity and a fake login first. The test images are
# built with a root certificate, so no check may say none was requested.
# ------------------------------------------------------------------------------

import json
import os
import time

import pytest

from scenario_helpers import RunSandbox, docker_exec, selfcheck_problem_list, step


# ------------------------------------------------------------------------------
# test_init_and_selfcheck_pass: init, then selfcheck, every line a PASS
# ------------------------------------------------------------------------------
# plant git identity and fake login -> sbx-init -> sbx-selfcheck -> every line
# PASS, count = the agent's
# ------------------------------------------------------------------------------

def test_init_and_selfcheck_pass(sandbox: RunSandbox, request: pytest.FixtureRequest):
    agent = sandbox.agent
    plant_text = f"init-selfcheck-{os.getpid()}-{int(time.time())}"
    login_file = sandbox.state_dir / agent.config_dir_name / agent.login_file

    def remove_planted_state() -> None:
        docker_exec(sandbox.container, "git config --global --unset user.name; git config --global --unset user.email")
        login_file.unlink(missing_ok=True)

    request.addfinalizer(remove_planted_state)

    with step("plant git identity and fake login"):
        identity = docker_exec(
            sandbox.container,
            f"git config --global user.name {plant_text} && "
            f"git config --global user.email {plant_text}@example.invalid",
        )

        assert identity.returncode == 0, identity.stderr

        login_file.parent.mkdir(parents=True, exist_ok=True)
        login_file.write_text(json.dumps({"fake": plant_text}) + "\n", encoding="utf-8")

    with step("sbx-init passes"):
        init = docker_exec(sandbox.container, "sbx-init", 600)
        expected_line = f"sbx-init: {agent.init_step_count} steps passed; run sbx-selfcheck to check the sandbox"
        output_line_list = init.stdout.strip().splitlines()

        assert init.returncode == 0, f"sbx-init exited {init.returncode}\n{init.stdout}\n{init.stderr}"
        assert output_line_list, "sbx-init printed nothing"
        assert output_line_list[-1] == expected_line, init.stdout

    with step("sbx-selfcheck passes"):
        selfcheck = docker_exec(sandbox.container, "sbx-selfcheck", 120)
        problem_list = selfcheck_problem_list(selfcheck.stdout, agent.selfcheck_count)

        assert not problem_list, "\n".join(problem_list) + f"\n\n{selfcheck.stdout}"
        assert selfcheck.returncode == 0, f"sbx-selfcheck exited {selfcheck.returncode}\n{selfcheck.stderr}"
