# ------------------------------------------------------------------------------
# sbx-list: the registered sandboxes with their status and directory
# ------------------------------------------------------------------------------
# One docker ps call gives every status, so the list matches docker ps -a. It
# only reads: no container, registry entry or directory is changed.
# ------------------------------------------------------------------------------

import os
import sys
from collections.abc import Mapping
from functools import partial
from pathlib import Path

from sbx.cli import SbxError, UsageError, run_command
from sbx.docker import Docker, container_state_map, run_docker, runs_older_image
from sbx.names import agent_image, check_name, container_name, image_tag
from sbx.registry import config_dir, entry_file, list_entry_names, read_entry, registry_dir


# ------------------------------------------------------------------------------
# Constants
# ------------------------------------------------------------------------------

COMMAND_NAME = "sbx-list"
_BROKEN_STATUS = "broken entry"
_OLDER_IMAGE_STATUS = "running, older image"
_OLDER_IMAGE_NOTE = (
    "older image: sbx-start NAME recreates it on the current image; "
    "that closes its open shells and Claude sessions"
)
_NO_SANDBOXES_LINE = "sbx-list: no sandboxes registered; register one with: sbx-add NAME HOST_PATH"
_LEFTOVER_LABEL = (
    "Containers with the sbx.name label but no registry entry "
    "(sbx-add NAME HOST_PATH registers one again):"
)
_CONTAINER_PREFIX = "sbx-"


# ------------------------------------------------------------------------------
# Status words
# ------------------------------------------------------------------------------
# Paused, restarting, exited, created, dead and removing all read stopped. The
# match is the whole container name, so sbx-demo-two is never the sandbox demo.
# ------------------------------------------------------------------------------

def _status_word(state: str) -> str:
    if state == "running":
        return "running"

    return "stopped"


def _status_of(name: str, state_map: dict[str, str]) -> str:
    state = state_map.get(container_name(name))

    if state is None:
        return "no container"

    return _status_word(state)


# ------------------------------------------------------------------------------
# The table
# ------------------------------------------------------------------------------
# A broken entry is a row; sbx-start NAME prints the reason.
# ------------------------------------------------------------------------------

def _format_row(name: str, status: str, path: str) -> str:
    return f"{name:<31} {status:<20} {path}"


def _row_of(registry: Path, name: str, tag: str, state_map: dict[str, str], docker: Docker) -> tuple[str, bool]:
    try:
        check_name(name)
        entry = read_entry(registry, name)
    except SbxError:
        return _format_row(name, _BROKEN_STATUS, str(entry_file(registry, name))), False

    status = _status_of(name, state_map)

    if status == "running" and runs_older_image(docker, name, agent_image(entry.agent, tag)):
        return _format_row(name, _OLDER_IMAGE_STATUS, entry.path), True

    return _format_row(name, status, entry.path), False


def _print_table(registry: Path, tag: str, state_map: dict[str, str], docker: Docker) -> bool:
    name_list = list_entry_names(registry)

    if not name_list:
        print(_NO_SANDBOXES_LINE)

        return False

    print(_format_row("NAME", "STATUS", "PATH"))

    older_image_found = False

    for name in name_list:
        row, is_older = _row_of(registry, name, tag, state_map, docker)
        print(row)

        if is_older:
            older_image_found = True

    return older_image_found


# ------------------------------------------------------------------------------
# Containers that have no registry entry
# ------------------------------------------------------------------------------
# For example the host-test sandbox, or one whose entry was deleted by hand.
# ------------------------------------------------------------------------------

def _has_entry(registry: Path, container: str) -> bool:
    if not container.startswith(_CONTAINER_PREFIX):
        return False

    return entry_file(registry, container[len(_CONTAINER_PREFIX):]).is_file()


def _print_leftovers(registry: Path, state_map: dict[str, str]) -> None:
    leftover_count = 0

    for container in sorted(state_map):
        if _has_entry(registry, container):
            continue

        if leftover_count == 0:
            print()
            print(_LEFTOVER_LABEL)

        leftover_count += 1
        print(f"  {container:<35} {_status_word(state_map[container])}")


# ------------------------------------------------------------------------------
# The command
# ------------------------------------------------------------------------------

def _list_sandboxes(argument_list: list[str], environ: Mapping[str, str], docker: Docker) -> None:
    if argument_list:
        raise UsageError("")

    registry = registry_dir(config_dir(environ))
    tag = image_tag(environ, COMMAND_NAME)
    state_map = container_state_map(docker)

    if state_map is None:
        raise SbxError("cannot read the containers from Docker; is Docker running?")

    older_image_found = _print_table(registry, tag, state_map, docker)

    if older_image_found:
        print(_OLDER_IMAGE_NOTE)

    _print_leftovers(registry, state_map)


def main(argument_list: list[str], environ: Mapping[str, str] = os.environ, docker: Docker = run_docker) -> int:
    return run_command(COMMAND_NAME, partial(_list_sandboxes, argument_list, environ, docker))


# ------------------------------------------------------------------------------
# Main / Entry Point
# ------------------------------------------------------------------------------

if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
