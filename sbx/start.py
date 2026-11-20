# ------------------------------------------------------------------------------
# sbx-start: starts a registered sandbox by name
# ------------------------------------------------------------------------------
# The directories are checked first, so a wrong entry never reaches Docker. A
# running sandbox on an older image is recreated on the current one, after a
# warning.
# ------------------------------------------------------------------------------

import os
import sys
from collections.abc import Mapping
from functools import partial
from pathlib import Path

from sbx.cli import REPO_DIR, UsageError, run_command
from sbx.docker import Docker, bring_up_sandbox, run_docker
from sbx.names import check_name, image_tag
from sbx.registry import config_dir, read_entry, registry_dir


# ------------------------------------------------------------------------------
# Constants
# ------------------------------------------------------------------------------

COMMAND_NAME = "sbx-start"


# ------------------------------------------------------------------------------
# The command
# ------------------------------------------------------------------------------

def _start_sandbox(argument_list: list[str], environ: Mapping[str, str], docker: Docker, repo_dir: Path) -> None:
    if len(argument_list) != 1:
        raise UsageError("NAME")

    name = argument_list[0]
    registry = registry_dir(config_dir(environ))
    tag = image_tag(environ, COMMAND_NAME)

    check_name(name)

    entry = read_entry(registry, name)

    bring_up_sandbox(COMMAND_NAME, docker, entry, tag, repo_dir, registry, environ)

    print(f"{COMMAND_NAME}: sbx-{name} is running")
    print(f"{COMMAND_NAME}: open a shell with: sbx-shell {name}")
    print(f"{COMMAND_NAME}: in a new or recreated container, run sbx-init there before the agent")


def main(
    argument_list: list[str],
    environ: Mapping[str, str] = os.environ,
    docker: Docker = run_docker,
    repo_dir: Path = REPO_DIR,
) -> int:
    return run_command(COMMAND_NAME, partial(_start_sandbox, argument_list, environ, docker, repo_dir))


# ------------------------------------------------------------------------------
# Main / Entry Point
# ------------------------------------------------------------------------------

if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
