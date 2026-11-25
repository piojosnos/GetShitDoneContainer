# --------------------------------------------------------------------------------
# The one place the sbx commands run Docker
# --------------------------------------------------------------------------------
# Docker is reached through run_docker only. A command takes it as a parameter
# (default run_docker), so a test passes a recorder and needs no Docker.
# --------------------------------------------------------------------------------

import os
import subprocess
from collections.abc import Callable, Mapping
from dataclasses import dataclass
from pathlib import Path

from sbx.cli import SbxError
from sbx.names import agent_image, container_name
from sbx.registry import Entry, entry_file


# --------------------------------------------------------------------------------
# Constants
# --------------------------------------------------------------------------------

_NOT_FOUND_EXIT_CODE = 127


# --------------------------------------------------------------------------------
# Running Docker
# --------------------------------------------------------------------------------
# A missing docker binary reads as Docker not answering. Queries capture stdout
# and drop stderr; long calls (capture False) inherit both.
# --------------------------------------------------------------------------------

@dataclass(frozen=True)
class DockerResult:
    returncode: int
    stdout: str


Docker = Callable[[list[str], Mapping[str, str] | None, bool], DockerResult]


def run_docker(
    argument_list: list[str],
    environ: Mapping[str, str] | None = None,
    capture: bool = True,
) -> DockerResult:
    stdout_target = subprocess.PIPE if capture else None
    stderr_target = subprocess.DEVNULL if capture else None

    try:
        completed = subprocess.run(
            ["docker", *argument_list],
            env=environ,
            stdin=subprocess.DEVNULL,
            stdout=stdout_target,
            stderr=stderr_target,
            text=True,
            errors="replace",
            check=False,
        )
    except OSError:
        return DockerResult(_NOT_FOUND_EXIT_CODE, "")

    return DockerResult(completed.returncode, completed.stdout or "")


# --------------------------------------------------------------------------------
# Questions about containers
# --------------------------------------------------------------------------------
# The label keeps the old-layout containers out. A failed docker ps is None,
# never an empty map, so no sandbox is shown as stopped or gone by mistake.
# --------------------------------------------------------------------------------

def container_state_map(docker: Docker) -> dict[str, str] | None:
    result = docker(["ps", "-a", "--filter", "label=sbx.name", "--format", "{{.Names}} {{.State}}"], None, True)

    if result.returncode != 0:
        return None

    state_map = {}

    for line in result.stdout.splitlines():
        part_list = line.split(maxsplit=1)

        if not part_list:
            continue

        state_map[part_list[0]] = part_list[1] if len(part_list) > 1 else ""

    return state_map


# --------------------------------------------------------------------------------

def sandbox_is_running(docker: Docker, name: str) -> bool:
    result = docker(["container", "inspect", "--format", "{{.State.Running}}", container_name(name)], None, True)

    if result.returncode != 0:
        return False

    return result.stdout.strip() == "true"


# --------------------------------------------------------------------------------

def runs_older_image(docker: Docker, name: str, image: str) -> bool:
    if not sandbox_is_running(docker, name):
        return False

    running = docker(["container", "inspect", "--format", "{{.Image}}", container_name(name)], None, True)

    if running.returncode != 0:
        return False

    current = docker(["image", "inspect", "--format", "{{.Id}}", image], None, True)

    if current.returncode != 0:
        return False

    running_id = running.stdout.strip()
    current_id = current.stdout.strip()

    return bool(running_id) and bool(current_id) and running_id != current_id


# --------------------------------------------------------------------------------
# Compose
# --------------------------------------------------------------------------------
# -p wins over COMPOSE_PROJECT_NAME and --env-file /dev/null keeps a .env file
# out. The environment is rebuilt for each call: every COMPOSE_ key of the caller
# is dropped, and SBX_NAME, SBX_DIR, SBX_AGENT and SBX_IMAGE_TAG come from the
# entry and the checked tag, never from the caller, so the caller cannot pick
# another project, directory or image.
# --------------------------------------------------------------------------------

def compose_command(
    entry: Entry,
    tag: str,
    repo_dir: Path,
    argument_list: list[str],
    environ: Mapping[str, str],
) -> tuple[list[str], dict[str, str]]:
    compose_environ = {}

    for key, value in environ.items():
        if key.startswith("COMPOSE_"):
            continue

        compose_environ[key] = value

    compose_environ["SBX_NAME"] = entry.name
    compose_environ["SBX_DIR"] = entry.path
    compose_environ["SBX_AGENT"] = entry.agent
    compose_environ["SBX_IMAGE_TAG"] = tag

    compose_argument_list = [
        "compose",
        "--env-file",
        "/dev/null",
        "-p",
        container_name(entry.name),
        "-f",
        str(repo_dir / "compose.yml"),
        *argument_list,
    ]

    return compose_argument_list, compose_environ


# --------------------------------------------------------------------------------

def run_compose(
    docker: Docker,
    entry: Entry,
    tag: str,
    repo_dir: Path,
    argument_list: list[str],
    environ: Mapping[str, str],
    capture: bool = False,
) -> DockerResult:
    compose_argument_list, compose_environ = compose_command(entry, tag, repo_dir, argument_list, environ)

    return docker(compose_argument_list, compose_environ, capture)


# --------------------------------------------------------------------------------
# Refusals before a start
# --------------------------------------------------------------------------------
# Docker would make a missing bind source as root, so the directories come first.
# With Docker stopped every image and container looks missing, so Docker must
# answer before an image counts as missing, or sbx-upgrade would be the wrong
# advice.
# --------------------------------------------------------------------------------

def check_sandbox_dirs(entry: Entry, registry: Path) -> None:
    for dir_name in [entry.name, "state"]:
        if not os.path.isdir(f"{entry.path}/{dir_name}"):
            raise SbxError(
                f"missing {entry.path}/{dir_name}; create it with mkdir -p, "
                f"or fix the path in {entry_file(registry, entry.name)}"
            )


# --------------------------------------------------------------------------------

def require_docker(docker: Docker) -> None:
    result = docker(["info"], None, True)

    if result.returncode != 0:
        raise SbxError("cannot reach Docker; is Docker running?")


# --------------------------------------------------------------------------------

def require_images(docker: Docker, entry: Entry, tag: str) -> None:
    require_docker(docker)

    image = agent_image(entry.agent, tag)
    result = docker(["image", "inspect", image], None, True)

    if result.returncode != 0:
        raise SbxError(
            f"{image} is not built; run: sbx-upgrade {entry.name} (it builds the images and starts the sandbox)"
        )


# --------------------------------------------------------------------------------
# Bringing a sandbox up
# --------------------------------------------------------------------------------
# lead says why and ends with the recreate or the removal, e.g. "is running;
# removing it": one wording for every command that recreates or removes a sandbox.
# A running sandbox on an older image is recreated by up, after the warning.
# --------------------------------------------------------------------------------

def warn_sessions_close(command_name: str, name: str, lead: str) -> None:
    print(f"{command_name}: {container_name(name)} {lead} will close its open shells and Claude sessions")


# --------------------------------------------------------------------------------

def bring_up_sandbox(
    command_name: str,
    docker: Docker,
    entry: Entry,
    tag: str,
    repo_dir: Path,
    registry: Path,
    environ: Mapping[str, str],
) -> None:
    check_sandbox_dirs(entry, registry)
    require_images(docker, entry, tag)

    if runs_older_image(docker, entry.name, agent_image(entry.agent, tag)):
        warn_sessions_close(command_name, entry.name, "runs on an older image; recreating it on the new one")

    result = run_compose(docker, entry, tag, repo_dir, ["up", "-d", "--wait"], environ)

    if result.returncode != 0:
        raise SbxError(f"docker compose up failed; docker logs {container_name(entry.name)} shows why")
