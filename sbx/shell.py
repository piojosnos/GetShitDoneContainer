# --------------------------------------------------------------------------------
# sbx-shell: opens a bash shell in a registered sandbox, starting it when needed
# --------------------------------------------------------------------------------
# The shell is bash in the project directory for every agent. In a new or
# recreated container, run sbx-init there first, then sbx-claude or sbx-cursor.
# A running sandbox is entered as it is, never recreated, so its other shells and
# agent sessions stay open.
# --------------------------------------------------------------------------------

import os
import sys
from collections.abc import Callable, Mapping
from functools import partial
from pathlib import Path

from sbx.cli import REPO_DIR, UsageError, run_command
from sbx.docker import Docker, bring_up_sandbox, run_docker, sandbox_is_running
from sbx.names import check_name, container_name, image_tag
from sbx.registry import config_dir, read_entry, registry_dir


# --------------------------------------------------------------------------------
# Constants
# --------------------------------------------------------------------------------

COMMAND_NAME = "sbx-shell"
_WORKSPACE_DIR = "/home/sandbox/workspace"

ExecFunction = Callable[[str, list[str], Mapping[str, str]], None]


# --------------------------------------------------------------------------------
# Handing over the terminal
# --------------------------------------------------------------------------------
# The one docker call that keeps stdin, because the terminal is the shell's. The
# exec replaces this process, so the exit status of the shell and its Ctrl-C reach
# the caller; uv stays the parent process, and the host run proves that it passes
# both on. The exec is a parameter so a test records the call and stays alive.
# --------------------------------------------------------------------------------

def _open_shell(name: str, environ: Mapping[str, str], exec_function: ExecFunction) -> None:
    argument_list = ["docker", "exec", "-it", "-w", f"{_WORKSPACE_DIR}/{name}", container_name(name), "bash"]

    sys.stdout.flush()
    sys.stderr.flush()
    exec_function("docker", argument_list, dict(environ))


# --------------------------------------------------------------------------------
# The command
# --------------------------------------------------------------------------------

def _shell_into_sandbox(
    argument_list: list[str],
    environ: Mapping[str, str],
    docker: Docker,
    repo_dir: Path,
    exec_function: ExecFunction,
) -> None:
    if len(argument_list) != 1:
        raise UsageError("NAME")

    name = argument_list[0]
    registry = registry_dir(config_dir(environ))
    tag = image_tag(environ, COMMAND_NAME)

    check_name(name)

    entry = read_entry(registry, name)

    if not sandbox_is_running(docker, name):
        bring_up_sandbox(COMMAND_NAME, docker, entry, tag, repo_dir, registry, environ)

    _open_shell(name, environ, exec_function)


# --------------------------------------------------------------------------------

def main(
    argument_list: list[str],
    environ: Mapping[str, str] = os.environ,
    docker: Docker = run_docker,
    repo_dir: Path = REPO_DIR,
    exec_function: ExecFunction = os.execvpe,
) -> int:
    return run_command(
        COMMAND_NAME,
        partial(_shell_into_sandbox, argument_list, environ, docker, repo_dir, exec_function),
    )


# --------------------------------------------------------------------------------
# Main / Entry Point
# --------------------------------------------------------------------------------

if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
