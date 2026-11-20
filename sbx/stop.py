# ------------------------------------------------------------------------------
# sbx-stop: stops a registered sandbox by name; the container and every file stay
# ------------------------------------------------------------------------------
# Compose stop keeps the container, so the next sbx-start reuses it. It checks no
# directory, so a sandbox whose directory moved can still be stopped.
# ------------------------------------------------------------------------------

import os
import sys
from collections.abc import Mapping
from functools import partial
from pathlib import Path

from sbx.cli import REPO_DIR, SbxError, UsageError, run_command
from sbx.docker import Docker, run_compose, run_docker
from sbx.names import check_name, container_name, image_tag
from sbx.registry import config_dir, read_entry, registry_dir


# ------------------------------------------------------------------------------
# Constants
# ------------------------------------------------------------------------------

COMMAND_NAME = "sbx-stop"


# ------------------------------------------------------------------------------
# The command
# ------------------------------------------------------------------------------

def _stop_sandbox(argument_list: list[str], environ: Mapping[str, str], docker: Docker, repo_dir: Path) -> None:
    if len(argument_list) != 1:
        raise UsageError("NAME")

    name = argument_list[0]
    registry = registry_dir(config_dir(environ))
    tag = image_tag(environ, COMMAND_NAME)

    check_name(name)

    entry = read_entry(registry, name)
    result = run_compose(docker, entry, tag, repo_dir, ["stop"], environ)

    if result.returncode != 0:
        raise SbxError(f"docker compose stop failed for {container_name(name)}")

    print(f"{COMMAND_NAME}: {container_name(name)} is stopped; nothing in {entry.path} was changed")


def main(
    argument_list: list[str],
    environ: Mapping[str, str] = os.environ,
    docker: Docker = run_docker,
    repo_dir: Path = REPO_DIR,
) -> int:
    return run_command(COMMAND_NAME, partial(_stop_sandbox, argument_list, environ, docker, repo_dir))


# ------------------------------------------------------------------------------
# Main / Entry Point
# ------------------------------------------------------------------------------

if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
