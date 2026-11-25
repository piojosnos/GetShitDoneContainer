# ------------------------------------------------------------------------------
# Scenarios: the first run in a fresh sandbox, and the relink after a pull
# ------------------------------------------------------------------------------
# Both scenarios change the best-practices clone, so each works on a throwaway
# sandbox of its own and the shared sandbox keeps its clean clone. The origin they
# use is a bare copy of the run's origin, placed inside the throwaway sandbox
# directory so the container sees it under the workspace path; a push never
# changes the run's origin. Everything that differs between the agents (wrapper,
# binary, version pin, links step, step count, rules file extension) comes from AgentSpec.
# ------------------------------------------------------------------------------

import json
import os
import time
from pathlib import Path

from agent_specs import AgentSpec
from sbx.build import read_pins
from scenario_helpers import (
    REPO_DIR,
    CommandResult,
    RunSandbox,
    container_is_running,
    describe_result,
    docker_exec,
    register_sandbox,
    run_sbx,
    run_timeout,
    step,
    throwaway_sandbox,
)

_WORKSPACE = "/home/sandbox/workspace"
_ORIGIN_DIR_NAME = "origin.git"
_ORIGIN_URL = f"{_WORKSPACE}/{_ORIGIN_DIR_NAME}"
_CLONE_DIR_NAME = "best-practices"
_CLONE_DIR = f"{_WORKSPACE}/{_CLONE_DIR_NAME}"
_AGENTS_BIN_DIR = "/opt/sbx/agents/bin"
_STAND_IN_DIR = "/tmp/sbx-stand-in-bin"
_PUSHED_BRANCH = "first-run-change"
_KEPT_SKILL = "sbx-fixture-one"
_DROPPED_SKILL = "sbx-fixture-two"
_SUPPORT_DIR = REPO_DIR / "tests" / "integration" / "support" / "best-practices"
_INIT_SECONDS = 600
_SETTINGS_KEY = "relinkSentinel"
_CONTAINER_GIT_OPTIONS = "-c user.name=sbx-hosttest -c user.email=sbx-hosttest@example.invalid -c commit.gpgsign=false"
_HOST_GIT_ENVIRON_UPDATE = {
    "GIT_CONFIG_GLOBAL": "/dev/null",
    "GIT_CONFIG_NOSYSTEM": "1",
    "GIT_AUTHOR_NAME": "sbx-hosttest",
    "GIT_AUTHOR_EMAIL": "sbx-hosttest@example.invalid",
    "GIT_COMMITTER_NAME": "sbx-hosttest",
    "GIT_COMMITTER_EMAIL": "sbx-hosttest@example.invalid",
}


# ------------------------------------------------------------------------------
# Git on the host
# ------------------------------------------------------------------------------
# The host user's own git configuration and identity are never used.
# ------------------------------------------------------------------------------

def _git_environ() -> dict[str, str]:
    environ = dict(os.environ)
    environ.update(_HOST_GIT_ENVIRON_UPDATE)

    return environ


def _git(argument_list: list[str], cwd: Path | None = None) -> CommandResult:
    return run_timeout(["git", *argument_list], 120, _git_environ(), cwd=cwd)


def _assert_git(result: CommandResult, what: str) -> None:
    assert result.returncode == 0, f"{what} failed: {describe_result(result)}"


# ------------------------------------------------------------------------------
# Reading command output
# ------------------------------------------------------------------------------

def _last_line(text: str) -> str:
    line_list = text.strip().splitlines()

    if not line_list:
        return ""

    return line_list[-1]


def _line_starting_with(text: str, prefix: str) -> str | None:
    for line in text.splitlines():
        if line.startswith(prefix):
            return line

    return None


def _fix_line_naming(text: str, word: str) -> str | None:
    for line in text.splitlines():
        stripped = line.strip()

        if stripped.startswith("fix: ") and word in stripped:
            return stripped

    return None


def _init_summary_line(agent: AgentSpec) -> str:
    return f"sbx-init: {agent.init_step_count} steps passed; run sbx-selfcheck to check the sandbox"


# ------------------------------------------------------------------------------
# What a link reaches
# ------------------------------------------------------------------------------
# Both agents link the generated rules directory of the clone whole and one link
# per generated skill. live_target gives a directory an agent config link reaches
# and a file in it, so one scenario reads a change through a link for either agent:
# the clone path is CLONE/generated/AGENT/DIR/FILE and the state path is
# CONFIG/DIR/FILE.
# ------------------------------------------------------------------------------

def _generated_dir(agent: AgentSpec) -> str:
    return f"generated/{agent.name}"


def _live_target(agent: AgentSpec) -> tuple[str, str]:
    return "rules", f"sbx-fixture-always{agent.rules_extension}"


def _config_dir(agent: AgentSpec) -> str:
    return f"{_WORKSPACE}/state/{agent.config_dir_name}"


def _fixture_skill_name_list(agent: AgentSpec) -> list[str]:
    name_list = []

    for skill_dir in sorted((_SUPPORT_DIR / _generated_dir(agent) / "skills").iterdir()):
        name_list.append(skill_dir.name)

    return name_list


def _read_link(container: str, path: str) -> str:
    return docker_exec(container, f"readlink {path}").stdout.strip()


def _link_problem_list(container: str, agent: AgentSpec, skill_name_list: list[str]) -> list[str]:
    problem_list = []
    config_dir = _config_dir(agent)
    expected_rules_link = f"../../best-practices/{_generated_dir(agent)}/rules"
    rules_link = _read_link(container, f"{config_dir}/rules")

    if rules_link != expected_rules_link:
        problem_list.append(f"the rules link is {rules_link!r}, expected {expected_rules_link!r}")

    for skill_name in skill_name_list:
        skill_link = _read_link(container, f"{config_dir}/skills/{skill_name}")
        expected_link = f"../../../best-practices/{_generated_dir(agent)}/skills/{skill_name}"

        if skill_link != expected_link:
            problem_list.append(f"the link of skill {skill_name} is {skill_link!r}, expected {expected_link!r}")

    return problem_list


# ------------------------------------------------------------------------------
# The user's settings key
# ------------------------------------------------------------------------------
# settings.json may already hold what the GSD sync wrote, so the key is added to
# the existing object and only the key is checked afterwards.
# ------------------------------------------------------------------------------

def _plant_settings_key(settings_file: Path, value: str) -> None:
    settings = {}

    if settings_file.is_file():
        settings = json.loads(settings_file.read_text(encoding="utf-8"))

    settings[_SETTINGS_KEY] = value
    settings_file.parent.mkdir(parents=True, exist_ok=True)
    settings_file.write_text(json.dumps(settings, indent=2) + "\n", encoding="utf-8")


def _settings_key_problem(settings_file: Path, value: str) -> str | None:
    if not settings_file.is_file():
        return f"{settings_file} is gone after sbx-init"

    try:
        settings = json.loads(settings_file.read_text(encoding="utf-8"))
    except json.JSONDecodeError as e:
        return f"{settings_file} is no longer JSON after sbx-init: {e}"

    if not isinstance(settings, dict) or settings.get(_SETTINGS_KEY) != value:
        return f"the key {_SETTINGS_KEY} of {settings_file} is missing or changed after sbx-init"

    return None


# ------------------------------------------------------------------------------
# Making a throwaway sandbox with its own origin
# ------------------------------------------------------------------------------

def _start_sandbox_with_origin(
    sandbox: RunSandbox,
    hosttest_env: dict[str, str],
    best_practices_origin: Path,
    sandbox_cleanup: list[str],
) -> None:
    add = register_sandbox(sandbox, hosttest_env, sandbox_cleanup)

    assert add.returncode == 0, f"sbx-add failed: {describe_result(add)}"

    copy = _git(["clone", "-q", "--bare", str(best_practices_origin), str(sandbox.sandbox_dir / _ORIGIN_DIR_NAME)])

    _assert_git(copy, "git clone --bare of the fixture origin into the sandbox directory")

    start = run_sbx("sbx-start", [sandbox.name], hosttest_env)

    assert start.returncode == 0, f"sbx-start failed: {describe_result(start)}"
    assert container_is_running(sandbox.container), f"{sandbox.container} is not running after sbx-start"


# ------------------------------------------------------------------------------
# The stand-in agent
# ------------------------------------------------------------------------------
# A stand-in binary in a directory of its own replaces that directory at the front
# of the PATH with the agents directory, which is the PATH the agent wrapper hands
# the real agent, then starts a login shell that reports where it finds the agent.
# The image's login files run for real, so a login file that reset the PATH shows.
# ------------------------------------------------------------------------------

def _stand_in_session_script(agent: AgentSpec) -> str:
    stand_in_file = f"{_STAND_IN_DIR}/{agent.binary}"

    return (
        f"mkdir -p {_STAND_IN_DIR} && "
        f"printf '%s\\n' '#!/bin/sh' 'PATH={_AGENTS_BIN_DIR}:${{PATH#{_STAND_IN_DIR}:}}' 'export PATH' "
        f"\"exec bash -lc 'command -v {agent.binary}'\" > {stand_in_file} && "
        f"chmod 755 {stand_in_file}; "
        f"SBX_AGENT_BIN_DIR={_STAND_IN_DIR} {agent.wrapper}; "
        f"session_status=$?; rm -rf {_STAND_IN_DIR}; exit $session_status"
    )


# ------------------------------------------------------------------------------
# test_first_run_refuses_then_inits_from_the_clone
# ------------------------------------------------------------------------------
# fresh sandbox: wrapper refuses -> sbx-init stops at the links step -> clone runs
# init -> links, push, agent starts
# ------------------------------------------------------------------------------

def test_first_run_refuses_then_inits_from_the_clone(
    agent: AgentSpec,
    test_images: None,
    hosttest_env: dict[str, str],
    run_dir: Path,
    best_practices_origin: Path,
    sandbox_cleanup: list[str],
):
    sandbox = throwaway_sandbox("first", agent, run_dir)
    container = sandbox.container
    config_dir = _config_dir(agent)
    pin_map = read_pins(REPO_DIR / "versions.env")
    clone_command = f"BEST_PRACTICES_REPO_URL={_ORIGIN_URL} sbx-best-practices-clone"
    live_dir, live_file = _live_target(agent)
    sync_output = ""

    with step("make the sandbox, give it its own origin and start it without sbx-init"):
        _start_sandbox_with_origin(sandbox, hosttest_env, best_practices_origin, sandbox_cleanup)

    with step("the agent wrapper refuses before init"):
        refused = docker_exec(container, f"{agent.wrapper} --version")

        assert refused.returncode != 0, f"{agent.wrapper} started before sbx-init: {describe_result(refused)}"
        assert "run sbx-init first" in refused.stderr, f"the refusal does not say to run sbx-init first: {describe_result(refused)}"
        assert refused.stdout == "", f"{agent.wrapper} printed output before sbx-init: {describe_result(refused)}"

    with step("the agent is off the PATH"):
        plain_shell = docker_exec(container, f"command -v {agent.binary}")
        login_shell = docker_exec(container, f"bash -lc 'command -v {agent.binary}'")

        assert plain_shell.returncode != 0 and not plain_shell.stdout.strip(), (
            f"a plain shell found {agent.binary}: {describe_result(plain_shell)}"
        )
        assert login_shell.returncode != 0 and not login_shell.stdout.strip(), (
            f"a plain login shell found {agent.binary}: {describe_result(login_shell)}"
        )

    with step("sbx-init without a clone stops at the links step"):
        init = docker_exec(container, "sbx-init", _INIT_SECONDS)
        sync_output += init.stdout + init.stderr

        assert init.returncode == 1, f"sbx-init without a clone did not exit 1: {describe_result(init)}"
        assert _line_starting_with(init.stdout, f"FAIL: {agent.links_step}: ") is not None, (
            f"no FAIL line for {agent.links_step}: {describe_result(init)}"
        )
        assert _fix_line_naming(init.stdout, "sbx-best-practices-clone") is not None, (
            f"no fix line names sbx-best-practices-clone: {describe_result(init)}"
        )
        assert _last_line(init.stdout) == f"sbx-init: stopped at {agent.links_step}", describe_result(init)

    with step("the clone runs sbx-init"):
        clone = docker_exec(container, clone_command, _INIT_SECONDS)
        sync_output += clone.stdout + clone.stderr

        assert clone.returncode == 0, f"sbx-best-practices-clone failed: {describe_result(clone)}"
        assert _last_line(clone.stdout) == _init_summary_line(agent), describe_result(clone)

    with step("the links point into the clone"):
        problem_list = _link_problem_list(container, agent, _fixture_skill_name_list(agent))
        read_through = docker_exec(container, f"cat {config_dir}/{live_dir}/{live_file}")
        fixture_text = (_SUPPORT_DIR / live_dir / live_file).read_text(encoding="utf-8")

        assert not problem_list, "\n".join(problem_list)
        assert read_through.stdout == fixture_text, (
            f"{live_dir}/{live_file} read through the link differs from the fixture: {describe_result(read_through)}"
        )

    with step("a second clone changes nothing"):
        again = docker_exec(container, clone_command, _INIT_SECONDS)

        assert again.returncode == 1, f"a second sbx-best-practices-clone did not exit 1: {describe_result(again)}"
        assert "already exists; nothing was changed" in again.stderr, describe_result(again)
        assert "sbx-init" in again.stderr, f"the second clone does not name sbx-init: {describe_result(again)}"

    with step("the remote is the given URL"):
        remote = docker_exec(container, f"git -C {_CLONE_DIR} remote get-url origin")

        assert remote.stdout.strip() == _ORIGIN_URL, f"the remote of the clone is {remote.stdout.strip()!r}, expected {_ORIGIN_URL!r}"

    with step("a push reaches the origin"):
        push = docker_exec(
            container,
            f"cd {_CLONE_DIR} && git checkout -q -b {_PUSHED_BRANCH} && "
            f"echo first-run-change >> {live_dir}/{live_file} && "
            f"git {_CONTAINER_GIT_OPTIONS} commit -q -am first-run-change && "
            f"git push -q origin {_PUSHED_BRANCH}",
        )
        origin_dir = sandbox.sandbox_dir / _ORIGIN_DIR_NAME
        pushed = _git(["rev-parse", "--verify", "-q", f"refs/heads/{_PUSHED_BRANCH}"], cwd=origin_dir)
        origin_main = _git(["rev-parse", "main"], cwd=origin_dir)
        run_main = _git(["rev-parse", "main"], cwd=best_practices_origin)

        assert push.returncode == 0, f"the push failed: {describe_result(push)}"
        assert pushed.returncode == 0, f"the branch {_PUSHED_BRANCH} is not in the origin: {describe_result(pushed)}"
        assert origin_main.returncode == 0 and origin_main.stdout == run_main.stdout, (
            f"main of the pushed origin is {origin_main.stdout.strip()!r}, the run's origin has {run_main.stdout.strip()!r}"
        )

    with step("the agent starts after init"):
        version_pin = pin_map[agent.version_pin]
        started = docker_exec(container, f"{agent.wrapper} --version")

        assert started.returncode == 0, f"{agent.wrapper} --version failed after init: {describe_result(started)}"
        assert version_pin in started.stdout, (
            f"{agent.wrapper} --version did not print the pin {version_pin}: {describe_result(started)}"
        )

    with step("a login shell inside an agent session finds the agents directory"):
        session = docker_exec(container, _stand_in_session_script(agent))
        plain_login = docker_exec(container, f"bash -lc 'command -v {agent.binary}'")

        assert session.returncode == 0 and session.stdout.strip() == f"{_AGENTS_BIN_DIR}/{agent.binary}", (
            f"a login shell inside a {agent.wrapper} session did not find {_AGENTS_BIN_DIR}/{agent.binary}; "
            f"a login file may have reset the PATH the wrapper set: {describe_result(session)}"
        )
        assert plain_login.returncode != 0 and not plain_login.stdout.strip(), (
            f"a plain login shell found {agent.binary}: {describe_result(plain_login)}"
        )

    with step("GSD is synced at the pin"):
        gsd_pin = pin_map["GSD_CORE_VERSION"]
        synced = docker_exec(container, f"cat {config_dir}/gsd-core/VERSION")

        assert synced.stdout.strip() == gsd_pin, (
            f"{config_dir}/gsd-core/VERSION holds {synced.stdout.strip()!r}, the GSD_CORE_VERSION pin is {gsd_pin!r}"
        )
        assert "npx" not in sync_output, f"the sbx-init output names npx:\n{sync_output}"
        assert "@latest" not in sync_output, f"the sbx-init output names @latest:\n{sync_output}"


# ------------------------------------------------------------------------------
# test_relink_after_a_pull
# ------------------------------------------------------------------------------
# edit on the host and pull in the sandbox are live -> drop a skill -> sbx-init
# relinks, keeps your files
# ------------------------------------------------------------------------------

def test_relink_after_a_pull(
    agent: AgentSpec,
    test_images: None,
    hosttest_env: dict[str, str],
    run_dir: Path,
    best_practices_origin: Path,
    sandbox_cleanup: list[str],
):
    sandbox = throwaway_sandbox("relink", agent, run_dir)
    container = sandbox.container
    config_dir = _config_dir(agent)
    clone_dir = sandbox.sandbox_dir / _CLONE_DIR_NAME
    state_config_dir = sandbox.state_dir / agent.config_dir_name
    live_dir, live_file = _live_target(agent)
    sentinel_text = f"relink-{os.getpid()}-{int(time.time())}"
    planted_path_list: list[Path] = []

    with step("make the sandbox with its clone, start it and run sbx-init"):
        _start_sandbox_with_origin(sandbox, hosttest_env, best_practices_origin, sandbox_cleanup)

        clone = _git(["clone", "-q", str(best_practices_origin), str(clone_dir)])

        _assert_git(clone, "git clone of the fixture origin for the sandbox")

        init = docker_exec(container, "sbx-init", _INIT_SECONDS)

        assert init.returncode == 0, f"sbx-init failed: {describe_result(init)}"
        assert _last_line(init.stdout) == _init_summary_line(agent), describe_result(init)

    with step("an edit on the host is live"):
        with open(clone_dir / live_dir / live_file, "a", encoding="utf-8") as edited_file:
            edited_file.write(f"{sentinel_text} edit\n")

        seen = docker_exec(container, f"cat {config_dir}/{live_dir}/{live_file}")

        assert f"{sentinel_text} edit" in seen.stdout, (
            f"an edit of the clone on the host is not in the sandbox at once: {describe_result(seen)}"
        )

    with step("a pull in the sandbox is live"):
        other_dir = run_dir / f"relink-other-{agent.name}"
        pulled_name = "relink-pulled.md"

        _assert_git(_git(["clone", "-q", str(sandbox.sandbox_dir / _ORIGIN_DIR_NAME), str(other_dir)]), "git clone of the origin copy")

        (other_dir / live_dir / pulled_name).write_text(f"{sentinel_text}\n", encoding="utf-8")

        _assert_git(_git(["add", f"{live_dir}/{pulled_name}"], cwd=other_dir), "git add of the pulled file")
        _assert_git(_git(["commit", "-q", "-m", "add a pulled file"], cwd=other_dir), "git commit of the pulled file")
        _assert_git(_git(["push", "-q", "origin", "main"], cwd=other_dir), "git push to the origin copy")

        pull = docker_exec(
            container,
            f"git -C {_CLONE_DIR} pull -q --ff-only {_ORIGIN_URL} main",
        )
        pulled = docker_exec(container, f"cat {config_dir}/{live_dir}/{pulled_name}")

        assert pull.returncode == 0, f"the pull in the sandbox failed: {describe_result(pull)}"
        assert pulled.stdout.strip() == sentinel_text, (
            f"a pulled file is not in the sandbox at once: {describe_result(pulled)}"
        )

    with step("plant user files"):
        planted_text_map = {
            state_config_dir / "skills" / "relink-user-skill" / "SKILL.md": f"{sentinel_text}\n",
            state_config_dir / "relink-user-note.md": f"{sentinel_text}\n",
        }

        if agent.session_dir is not None:
            session_dir = state_config_dir / agent.session_dir.format(name=sandbox.name)
            planted_text_map[session_dir / "relink-session.jsonl"] = f"{sentinel_text}\n"
            planted_text_map[session_dir / "memory" / "relink-memory.md"] = f"{sentinel_text}\n"

        if agent.instructions_file is not None:
            planted_text_map[state_config_dir / agent.instructions_file] = f"{sentinel_text}\n"

        if agent.settings_file is not None:
            _plant_settings_key(state_config_dir / agent.settings_file, sentinel_text)

        for planted_path, planted_text in planted_text_map.items():
            planted_path.parent.mkdir(parents=True, exist_ok=True)
            planted_path.write_text(planted_text, encoding="utf-8")
            planted_path_list.append(planted_path)

    with step("drop a skill and relink"):
        drop = docker_exec(
            container,
            f"cd {_CLONE_DIR} && git rm -rq skills/{_DROPPED_SKILL} && "
            f"git {_CONTAINER_GIT_OPTIONS} commit -q -m 'drop a skill'",
        )
        relink = docker_exec(container, "sbx-init", _INIT_SECONDS)
        dropped_path = f"{config_dir}/skills/{_DROPPED_SKILL}"
        dropped_left = docker_exec(container, f"test -e {dropped_path} -o -L {dropped_path}")
        problem_list = _link_problem_list(container, agent, [_KEPT_SKILL])

        assert drop.returncode == 0, f"dropping the skill from the clone failed: {describe_result(drop)}"
        assert relink.returncode == 0, f"sbx-init after the drop failed: {describe_result(relink)}"
        assert _last_line(relink.stdout) == _init_summary_line(agent), describe_result(relink)
        assert dropped_left.returncode != 0, f"{dropped_path} is still there after sbx-init"
        assert not problem_list, "\n".join(problem_list)

    with step("the relink keeps your edits and files"):
        kept_problem_list = []
        edited_text = (clone_dir / live_dir / live_file).read_text(encoding="utf-8")

        if f"{sentinel_text} edit" not in edited_text:
            kept_problem_list.append(f"the uncommitted edit in {live_dir}/{live_file} of the clone is gone after sbx-init")

        if not (clone_dir / live_dir / "relink-pulled.md").is_file():
            kept_problem_list.append(f"the pulled file {live_dir}/relink-pulled.md is gone from the clone after sbx-init")

        for planted_path in planted_path_list:
            if not planted_path.is_file():
                kept_problem_list.append(f"{planted_path} is gone after sbx-init")
            elif planted_path.read_bytes() != f"{sentinel_text}\n".encode("utf-8"):
                kept_problem_list.append(f"{planted_path} changed after sbx-init")

        if agent.settings_file is not None:
            settings_problem = _settings_key_problem(state_config_dir / agent.settings_file, sentinel_text)

            if settings_problem is not None:
                kept_problem_list.append(settings_problem)

        assert not kept_problem_list, "\n".join(kept_problem_list)
