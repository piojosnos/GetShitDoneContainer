# ------------------------------------------------------------------------------
# The one place the sbx commands run Docker
# ------------------------------------------------------------------------------
# Docker is reached through run_docker only. A command takes it as a parameter
# (default run_docker), so a test passes a recorder and needs no Docker.
# ------------------------------------------------------------------------------

import subprocess
from collections.abc import Callable, Mapping
from dataclasses import dataclass

from sbx.names import container_name


# ------------------------------------------------------------------------------
# Constants
# ------------------------------------------------------------------------------

_NOT_FOUND_EXIT_CODE = 127


# ------------------------------------------------------------------------------
# Running Docker
# ------------------------------------------------------------------------------
# A missing docker binary reads as Docker not answering. Queries capture stdout
# and drop stderr; long calls (capture False) inherit both.
# ------------------------------------------------------------------------------

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


# ------------------------------------------------------------------------------
# Questions about containers
# ------------------------------------------------------------------------------
# The label keeps the old-layout containers out. A failed docker ps is None,
# never an empty map, so no sandbox is shown as stopped or gone by mistake.
# ------------------------------------------------------------------------------

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


def sandbox_is_running(docker: Docker, name: str) -> bool:
    result = docker(["container", "inspect", "--format", "{{.State.Running}}", container_name(name)], None, True)

    if result.returncode != 0:
        return False

    return result.stdout.strip() == "true"


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
