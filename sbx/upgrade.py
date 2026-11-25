# --------------------------------------------------------------------------------
# sbx-upgrade: rebuilds every image, then recreates one sandbox on them
# --------------------------------------------------------------------------------
# Options after NAME go to the build, for example --no-cache. A failed build
# leaves the sandbox as it was. The last line is the tool versions of the new
# container.
# --------------------------------------------------------------------------------

import os
import sys
from collections.abc import Callable, Mapping
from functools import partial
from pathlib import Path

from sbx import build
from sbx.cli import REPO_DIR, SbxError, UsageError, run_command
from sbx.docker import (
    Docker,
    check_sandbox_dirs,
    run_compose,
    run_docker,
    sandbox_is_running,
    warn_sessions_close,
)
from sbx.names import check_name, container_name, image_tag
from sbx.registry import Entry, config_dir, read_entry, registry_dir


# --------------------------------------------------------------------------------
# Constants
# --------------------------------------------------------------------------------

COMMAND_NAME = "sbx-upgrade"

BuildFunction = Callable[[list[str], Mapping[str, str], Docker, Path], int]


# --------------------------------------------------------------------------------
# The command
# --------------------------------------------------------------------------------
# --force-recreate, because a cached build keeps the image id and a plain up would
# keep the old container. Up also starts a stopped or new sandbox. The build runs
# in this process through build_function, so nothing below it runs until it has
# finished, and a failed build returns before anything touches the sandbox.
# --------------------------------------------------------------------------------

def _recreate_sandbox(docker: Docker, entry: Entry, tag: str, repo_dir: Path, environ: Mapping[str, str]) -> None:
    result = run_compose(docker, entry, tag, repo_dir, ["up", "-d", "--force-recreate", "--wait"], environ)

    if result.returncode != 0:
        raise SbxError(f"docker compose up failed after the build; docker logs {container_name(entry.name)} shows why")


# --------------------------------------------------------------------------------

def _print_tool_versions(docker: Docker, name: str) -> None:
    result = docker(["exec", container_name(name), "cat", "/etc/sbx/tool-versions"], None, False)

    if result.returncode != 0:
        raise SbxError(f"could not read /etc/sbx/tool-versions in {container_name(name)}")


# --------------------------------------------------------------------------------

def _upgrade_sandbox(
    argument_list: list[str],
    environ: Mapping[str, str],
    docker: Docker,
    repo_dir: Path,
    build_function: BuildFunction,
) -> None:
    if len(argument_list) < 1:
        raise UsageError("NAME [BUILD_OPTION...]")

    name = argument_list[0]
    option_list = argument_list[1:]
    registry = registry_dir(config_dir(environ))
    tag = image_tag(environ, COMMAND_NAME)

    check_name(name)

    entry = read_entry(registry, name)

    check_sandbox_dirs(entry, registry)

    if sandbox_is_running(docker, name):
        warn_sessions_close(COMMAND_NAME, name, "is running; after the build, recreating it")

    sys.stdout.flush()

    if build_function(option_list, environ, docker, repo_dir) != 0:
        raise SbxError(f"the build failed; {container_name(name)} was left as it was")

    _recreate_sandbox(docker, entry, tag, repo_dir, environ)

    print(f"{COMMAND_NAME}: the recreate removed the init marker; run sbx-init in the sandbox shell before the agent")
    print(f"{COMMAND_NAME}: {container_name(name)} runs on the new images", flush=True)

    _print_tool_versions(docker, name)


# --------------------------------------------------------------------------------

def main(
    argument_list: list[str],
    environ: Mapping[str, str] = os.environ,
    docker: Docker = run_docker,
    repo_dir: Path = REPO_DIR,
    build_function: BuildFunction = build.main,
) -> int:
    return run_command(
        COMMAND_NAME,
        partial(_upgrade_sandbox, argument_list, environ, docker, repo_dir, build_function),
    )


# --------------------------------------------------------------------------------
# Main / Entry Point
# --------------------------------------------------------------------------------

if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
