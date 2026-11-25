# --------------------------------------------------------------------------------
# Fixtures of the integration scenarios: run directory, images, test sandboxes
# --------------------------------------------------------------------------------
# The scenarios run the real sbx commands against real Docker. Every command gets
# a test registry in the run directory and SBX_IMAGE_TAG=test, so the registry and
# the images of your own sandboxes are never touched. Nothing here calls Docker
# when the file is imported or the tests are collected.
# --------------------------------------------------------------------------------

import os
import shutil
import sys
import tempfile
import time
from pathlib import Path

import pytest

from agent_specs import AGENT_SPEC_LIST, AgentSpec
from sbx.hosttest_names import (
    ROOT_CA_DIR_NAME,
    RUN_DIR_PREFIX,
    is_run_dir_mount,
    shared_sandbox_name,
    temp_base_dir,
)
from scenario_helpers import (
    REPO_DIR,
    CommandResult,
    RunSandbox,
    certificate_fingerprint,
    certificate_is_valid,
    docker_exec,
    inspect_container,
    make_root_certificate,
    progress,
    run_sbx,
    run_streamed,
    run_timeout,
)

SUPPORT_BEST_PRACTICES_DIR = REPO_DIR / "tests" / "integration" / "support" / "best-practices"
_INIT_MARKER = "/home/sandbox/.sbx-init-done"
_WORKSPACE_MOUNT = "/home/sandbox/workspace"
_FILE_SHARING_HINT = (
    "If the message says the mount was denied, the run directory is not under a directory "
    "shared with Docker Desktop (Settings, Resources, File sharing)."
)
_GIT_FIXTURE_ENVIRON_UPDATE = {
    "GIT_CONFIG_GLOBAL": "/dev/null",
    "GIT_CONFIG_NOSYSTEM": "1",
    "GIT_AUTHOR_NAME": "sbx-hosttest",
    "GIT_AUTHOR_EMAIL": "sbx-hosttest@example.invalid",
    "GIT_COMMITTER_NAME": "sbx-hosttest",
    "GIT_COMMITTER_EMAIL": "sbx-hosttest@example.invalid",
}


# --------------------------------------------------------------------------------
# Options
# --------------------------------------------------------------------------------

def pytest_addoption(parser: pytest.Parser) -> None:
    parser.addoption(
        "--keep",
        action="store_true",
        default=False,
        help="leave the test sandboxes and the run directory after the run",
    )


def _keep(request: pytest.FixtureRequest) -> bool:
    return bool(request.config.getoption("--keep"))


# --------------------------------------------------------------------------------
# Small helpers
# --------------------------------------------------------------------------------

def _describe(result: CommandResult) -> str:
    text = f"exit {result.returncode}"

    if result.timed_out:
        text += " (timed out)"

    return f"{text}\nstdout: {result.stdout.strip()}\nstderr: {result.stderr.strip()}"


def _require_success(result: CommandResult, what: str) -> None:
    if result.returncode != 0 or result.timed_out:
        pytest.fail(f"{what} failed: {_describe(result)}", pytrace=False)


def _git_environ() -> dict[str, str]:
    environ = dict(os.environ)
    environ.update(_GIT_FIXTURE_ENVIRON_UPDATE)

    return environ


# --------------------------------------------------------------------------------
# run_dir: the directory one run keeps everything in
# --------------------------------------------------------------------------------
# Made under the temp base (which Docker Desktop shares), resolved, with logs/ and
# cfg/ (the test registry). Removed at the end unless --keep.
# --------------------------------------------------------------------------------

@pytest.fixture(scope="session")
def run_dir(request: pytest.FixtureRequest):
    base_dir = temp_base_dir(os.environ)
    stamp = time.strftime("%Y%m%d-%H%M%S")
    created = tempfile.mkdtemp(prefix=f"{RUN_DIR_PREFIX}{stamp}.", dir=base_dir)
    run_path = Path(os.path.realpath(created))
    (run_path / "logs").mkdir()
    (run_path / "cfg").mkdir()

    progress(f"run directory: {run_path}")

    yield run_path

    if _keep(request):
        progress(f"--keep: the run directory stays: {run_path}")

        return

    shutil.rmtree(run_path, ignore_errors=True)


# --------------------------------------------------------------------------------
# root_ca_file: the certificate file the test images are built to trust
# --------------------------------------------------------------------------------
# The throwaway root is made once and reused while valid; its key is deleted at
# once. build-ca.pem holds your own SBX_CA_CERT first when set, then the test root.
# The file sits outside the run directory, which a sandbox mounts.
# --------------------------------------------------------------------------------

@pytest.fixture(scope="session")
def root_ca_file(run_dir: Path) -> Path:
    cert_dir = temp_base_dir(os.environ) / ROOT_CA_DIR_NAME
    cert_file = cert_dir / "root-ca.pem"
    build_file = cert_dir / "build-ca.pem"

    if not certificate_is_valid(cert_file):
        try:
            make_root_certificate(cert_file)
        except RuntimeError as e:
            pytest.fail(str(e), pytrace=False)

    own_text = ""
    own_file_text = os.environ.get("SBX_CA_CERT", "")

    if own_file_text:
        own_file = Path(own_file_text)

        if not own_file.is_file() or not os.access(own_file, os.R_OK):
            pytest.fail(f"SBX_CA_CERT is not a readable file: {own_file_text}", pytrace=False)

        own_text = own_file.read_text(encoding="utf-8") + "\n"

    temporary_file = build_file.with_name("build-ca.pem.tmp")
    temporary_file.write_text(own_text + cert_file.read_text(encoding="utf-8"), encoding="utf-8")
    os.replace(temporary_file, build_file)

    fingerprint = certificate_fingerprint(cert_file)
    progress(f"test root certificate: {cert_file}, SHA-256 {fingerprint}; the build trusts {build_file}")

    return build_file


# --------------------------------------------------------------------------------
# hosttest_env: the environment every command of a scenario runs with
# --------------------------------------------------------------------------------
# No SBX_ or COMPOSE_ value of the caller gets through. The decoy values prove
# the commands take everything from the registry and ignore the ambient shell.
# --------------------------------------------------------------------------------

@pytest.fixture(scope="session")
def hosttest_env(run_dir: Path, root_ca_file: Path) -> dict[str, str]:
    environ = {}

    for key, value in os.environ.items():
        if key.startswith("SBX_") or key.startswith("COMPOSE_") or key == "VIRTUAL_ENV":
            continue

        environ[key] = value

    environ["SBX_CONFIG_DIR"] = str(run_dir / "cfg")
    environ["SBX_IMAGE_TAG"] = "test"
    environ["SBX_CA_CERT"] = str(root_ca_file)
    environ["PATH"] = f"{REPO_DIR / 'bin'}{os.pathsep}{os.environ.get('PATH', '')}"
    environ["SBX_DIR"] = "/nonexistent-ambient"
    environ["SBX_NAME"] = "ambient"
    environ["SBX_AGENT"] = "ambient"
    environ["COMPOSE_PROJECT_NAME"] = "sbx-ambient"

    return environ


# --------------------------------------------------------------------------------
# test_images: builds the test images once per run
# --------------------------------------------------------------------------------
# build.sh with SBX_IMAGE_TAG=test, so the images your sandboxes run are not
# touched. A build warning about a default argument in a FROM line is a failure.
# --------------------------------------------------------------------------------

@pytest.fixture(scope="session")
def test_images(run_dir: Path, hosttest_env: dict[str, str]) -> None:
    info = run_timeout(["docker", "info"], 60, hosttest_env)

    if info.returncode != 0:
        pytest.fail("cannot reach Docker; is Docker running?", pytrace=False)

    log_file = run_dir / "logs" / "build-images.log"
    progress(f"building the test images; log: {log_file}")
    result = run_streamed([str(REPO_DIR / "build.sh")], 3600, hosttest_env, sys.stdout, log_file)

    if result.returncode != 0:
        pytest.fail(f"build.sh exited {result.returncode}; log: {log_file}", pytrace=False)

    if "InvalidDefaultArgInFrom" in result.stdout:
        pytest.fail(f"the build warned InvalidDefaultArgInFrom; log: {log_file}", pytrace=False)


# --------------------------------------------------------------------------------
# best_practices_origin: a local bare repo holding the fixture rules and skills
# --------------------------------------------------------------------------------
# A seed directory gets one commit on main and the bare repo is cloned from it.
# Host git config and identity are never used.
# --------------------------------------------------------------------------------

@pytest.fixture(scope="session")
def best_practices_origin(run_dir: Path) -> Path:
    origin_dir = run_dir / "best-practices-origin.git"
    seed_dir = run_dir / "best-practices-origin.seed"
    environ = _git_environ()

    shutil.copytree(SUPPORT_BEST_PRACTICES_DIR, seed_dir)

    command_list = [
        ["git", "init", "-q"],
        ["git", "symbolic-ref", "HEAD", "refs/heads/main"],
        ["git", "add", "."],
        ["git", "-c", "commit.gpgsign=false", "commit", "-q", "-m", "fixture best-practices repo"],
    ]

    for command in command_list:
        _require_success(run_timeout(command, 60, environ, cwd=seed_dir), " ".join(command))

    clone = run_timeout(["git", "clone", "-q", "--bare", str(seed_dir), str(origin_dir)], 60, environ)
    _require_success(clone, "git clone --bare of the fixture best-practices repo")

    return origin_dir


# --------------------------------------------------------------------------------
# sandbox_cleanup: the names of the sandboxes the run started
# --------------------------------------------------------------------------------
# A fixture appends a name as soon as the sandbox is registered. At the end each
# one goes through sbx-rm, unless --keep, and any test container left is named.
# --------------------------------------------------------------------------------

@pytest.fixture(scope="session")
def sandbox_cleanup(request: pytest.FixtureRequest, run_dir: Path, hosttest_env: dict[str, str]):
    name_list: list[str] = []

    yield name_list

    if _keep(request):
        progress(f"--keep: the test sandboxes stay: {', '.join(name_list)}")

        return

    for name in name_list:
        result = run_sbx("sbx-rm", [name, "--unregister", "--yes"], hosttest_env)

        if result.returncode != 0:
            progress(f"sbx-rm {name} failed: {_describe(result)}")

    left = run_timeout(["docker", "ps", "-a", "--filter", "name=sbx-hosttest", "--format", "{{.Names}}"], 60)

    if left.stdout.strip():
        progress(f"test containers still there: {' '.join(left.stdout.split())}")


# --------------------------------------------------------------------------------
# agent: the scenario runs once per agent
# --------------------------------------------------------------------------------

@pytest.fixture(scope="session", params=AGENT_SPEC_LIST, ids=[spec.name for spec in AGENT_SPEC_LIST])
def agent(request: pytest.FixtureRequest) -> AgentSpec:
    return request.param


# --------------------------------------------------------------------------------
# Leftover test containers
# --------------------------------------------------------------------------------
# A container of an interrupted run is removed only when its label and its
# workspace mount prove a test run; any other container of that name stops the
# fixture, naming it.
# --------------------------------------------------------------------------------

def _workspace_mount_source(inspected: dict) -> str:
    for mount in inspected.get("Mounts", []):
        if mount.get("Destination") == _WORKSPACE_MOUNT:
            return str(mount.get("Source", ""))

    return ""


def _remove_leftover_container(name: str, container: str) -> None:
    inspected = inspect_container(container)

    if inspected is None:
        return

    label_map = (inspected.get("Config") or {}).get("Labels") or {}
    label = label_map.get("sbx.name", "")
    source = _workspace_mount_source(inspected)

    if label != name or not is_run_dir_mount(source, temp_base_dir(os.environ)):
        pytest.fail(
            f"a container named {container} exists and is not a host-test container "
            f"(label sbx.name={label!r}, workspace mount {source!r}); it was left alone",
            pytrace=False,
        )

    run_timeout(["docker", "rm", "-f", container], 120)
    run_timeout(["docker", "network", "rm", f"{container}_default"], 60)


# --------------------------------------------------------------------------------
# shared_sandbox: one test sandbox per agent, made with the real commands
# --------------------------------------------------------------------------------
# add -> clone best-practices -> start -> sbx-init
# The directory name holds a space on purpose. A scenario gets the sandbox back
# in a known state from the sandbox fixture.
# --------------------------------------------------------------------------------

@pytest.fixture(scope="session")
def shared_sandbox(
    agent: AgentSpec,
    run_dir: Path,
    hosttest_env: dict[str, str],
    test_images: None,
    best_practices_origin: Path,
    sandbox_cleanup: list[str],
) -> RunSandbox:
    name = shared_sandbox_name(agent.name)
    container = f"sbx-{name}"
    sandbox_dir = run_dir / f"{agent.name} sandbox"

    _remove_leftover_container(name, container)

    add = run_sbx("sbx-add", [name, str(sandbox_dir), agent.name], hosttest_env)
    _require_success(add, f"sbx-add {name}")
    sandbox_cleanup.append(name)

    clone = run_timeout(
        ["git", "clone", "-q", str(best_practices_origin), str(sandbox_dir / "best-practices")],
        120,
        _git_environ(),
    )
    _require_success(clone, f"git clone of the fixture best-practices repo for {name}")

    start = run_sbx("sbx-start", [name], hosttest_env)

    if start.returncode != 0:
        pytest.fail(f"sbx-start {name} failed: {_describe(start)}\n{_FILE_SHARING_HINT}", pytrace=False)

    init = docker_exec(container, "sbx-init", 600)
    _require_success(init, f"sbx-init in {container}")

    return RunSandbox(
        name=name,
        agent=agent,
        sandbox_dir=sandbox_dir,
        project_dir=sandbox_dir / name,
        state_dir=sandbox_dir / "state",
        container=container,
        entry_file=run_dir / "cfg" / "sandboxes" / f"{name}.json",
    )


# --------------------------------------------------------------------------------
# sandbox: the shared sandbox back in a known state, for one scenario
# --------------------------------------------------------------------------------
# running, init done
# A scenario that stopped, recreated or upgraded the sandbox leaves nothing for
# the next one to repair: this starts it again and runs sbx-init when the marker
# is gone.
# --------------------------------------------------------------------------------

@pytest.fixture
def sandbox(shared_sandbox: RunSandbox, hosttest_env: dict[str, str]) -> RunSandbox:
    inspected = inspect_container(shared_sandbox.container)
    running = inspected is not None and inspected.get("State", {}).get("Running") is True

    if not running:
        start = run_sbx("sbx-start", [shared_sandbox.name], hosttest_env)

        if start.returncode != 0:
            pytest.fail(f"sbx-start {shared_sandbox.name} failed: {_describe(start)}", pytrace=False)

    marker = docker_exec(shared_sandbox.container, f"test -f {_INIT_MARKER}")

    if marker.returncode != 0:
        init = docker_exec(shared_sandbox.container, "sbx-init", 600)
        _require_success(init, f"sbx-init in {shared_sandbox.container}")

    return shared_sandbox
