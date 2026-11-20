# ------------------------------------------------------------------------------
# sbx-rm: removes a sandbox's container; with --unregister also its registry entry
# ------------------------------------------------------------------------------
# The only module that deletes a registry entry or removes a container, so what
# destroys data lives in one file. Compose takes the container and its network,
# never volumes or images. Nothing in the sandbox directory is read, written or
# deleted. A running sandbox goes only after a y on the terminal, or with --yes.
# A broken entry has no directory for Compose, so with --unregister its container
# is stopped and removed by name.
# ------------------------------------------------------------------------------

import os
import sys
from collections.abc import Callable, Mapping
from dataclasses import dataclass
from functools import partial
from pathlib import Path

from sbx.cli import REPO_DIR, SbxError, UsageError, print_notice, run_command
from sbx.docker import Docker, container_state_map, require_docker, run_compose, run_docker, sandbox_is_running, warn_sessions_close
from sbx.names import check_name, container_name, image_tag
from sbx.registry import Entry, config_dir, entry_file, read_entry, registry_dir


# ------------------------------------------------------------------------------
# Constants
# ------------------------------------------------------------------------------

COMMAND_NAME = "sbx-rm"
_USAGE_TEXT = "NAME [--unregister] [--yes]"
_MAX_ARGUMENT_COUNT = 3
_BROKEN_DIR_TEXT = "the sandbox directory"


# ------------------------------------------------------------------------------
# The arguments
# ------------------------------------------------------------------------------
# --unregister and --yes may come before or after the name, once each. A second
# name, or anything else after the name, is the usage.
# ------------------------------------------------------------------------------

@dataclass(frozen=True)
class Request:
    name: str
    unregister: bool
    skip_confirmation: bool


def _parse_arguments(argument_list: list[str]) -> Request:
    if len(argument_list) < 1 or len(argument_list) > _MAX_ARGUMENT_COUNT:
        raise UsageError(_USAGE_TEXT)

    name = ""
    unregister = False
    skip_confirmation = False

    for argument in argument_list:
        if argument == "--unregister":
            if unregister:
                raise UsageError(_USAGE_TEXT)

            unregister = True
        elif argument == "--yes":
            if skip_confirmation:
                raise UsageError(_USAGE_TEXT)

            skip_confirmation = True
        else:
            if name:
                raise UsageError(_USAGE_TEXT)

            name = argument

    if not name:
        raise UsageError(_USAGE_TEXT)

    return Request(name, unregister, skip_confirmation)


# ------------------------------------------------------------------------------
# The question for a running sandbox
# ------------------------------------------------------------------------------
# The question is read only when stdin is a terminal; a script without --yes is
# refused, so a pipe can never answer for the user. Anything but y or Y, an empty
# line or a closed input included, keeps the sandbox.
# ------------------------------------------------------------------------------

def _confirm_if_running(
    docker: Docker,
    name: str,
    skip_confirmation: bool,
    is_terminal: Callable[[], bool],
    read_answer: Callable[[str], str],
) -> None:
    if not sandbox_is_running(docker, name):
        return

    warn_sessions_close(COMMAND_NAME, name, "is running; removing it")
    sys.stdout.flush()

    if skip_confirmation:
        return

    if not is_terminal():
        raise SbxError(
            f"{container_name(name)} is running and there is no terminal to confirm on; "
            "add --yes to remove it anyway. Nothing was changed"
        )

    try:
        answer = read_answer(f"Remove the running {container_name(name)}? [y/N] ")
    except EOFError:
        answer = ""

    if answer in ("y", "Y"):
        return

    raise SbxError(f"{container_name(name)} was not removed; it still runs and nothing was changed")


# ------------------------------------------------------------------------------
# Taking the container down
# ------------------------------------------------------------------------------

def _remove_container(docker: Docker, entry: Entry, tag: str, repo_dir: Path, environ: Mapping[str, str]) -> None:
    result = run_compose(docker, entry, tag, repo_dir, ["down"], environ)

    if result.returncode != 0:
        raise SbxError(
            f"docker compose down failed for {container_name(entry.name)}; "
            f"the registry entry stays and nothing in {entry.path} was changed"
        )


# ------------------------------------------------------------------------------
# A broken entry: the container by name
# ------------------------------------------------------------------------------
# Compose needs the directory the entry lacks, so plain docker stops and removes
# the one container with that exact name; volumes stay. Only a container with the
# sbx.name label goes: a same-named container without it is not a sandbox and
# stays. Only with --unregister, because the entry goes too. Docker must answer,
# or a stopped Docker would read as no container and the entry would go while the
# container stays.
# ------------------------------------------------------------------------------

def _require_sandbox_label(docker: Docker, name: str) -> None:
    state_map = container_state_map(docker)

    if state_map is None:
        raise SbxError("could not list the sandbox containers; nothing was removed and the registry entry stays")

    if container_name(name) not in state_map:
        raise SbxError(
            f"the container {container_name(name)} has no sbx.name label, so it is not a sandbox container; "
            "nothing was removed and the registry entry stays"
        )


def _remove_broken_sandbox(
    docker: Docker,
    request: Request,
    file: Path,
    problem: SbxError | None,
    is_terminal: Callable[[], bool],
    read_answer: Callable[[str], str],
) -> None:
    name = request.name

    if not request.unregister:
        print_notice(COMMAND_NAME, str(problem))

        raise SbxError(
            f"the entry is broken, so {container_name(name)} cannot be taken down with Compose; "
            f"sbx-rm {name} --unregister removes the container by name and clears the entry"
        )

    require_docker(docker)

    if docker(["container", "inspect", container_name(name)], None, True).returncode != 0:
        return

    _require_sandbox_label(docker, name)

    print(f"{COMMAND_NAME}: the entry {file} is broken; removing the container {container_name(name)} by name")

    _confirm_if_running(docker, name, request.skip_confirmation, is_terminal, read_answer)

    if docker(["stop", container_name(name)], None, True).returncode != 0:
        raise SbxError(f"docker stop failed for {container_name(name)}; the registry entry stays")

    if docker(["rm", container_name(name)], None, True).returncode != 0:
        raise SbxError(f"Docker could not remove the container {container_name(name)}; the registry entry stays")


# ------------------------------------------------------------------------------
# Deleting the entry, the only delete here
# ------------------------------------------------------------------------------
# Both the Compose path and the broken-entry path end here.
# ------------------------------------------------------------------------------

def _unregister_sandbox(file: Path, name: str, entry: Entry | None, dir_text: str) -> None:
    try:
        file.unlink()
    except OSError:
        raise SbxError(
            f"could not delete {file}; the container is gone and nothing in {dir_text} was changed"
        ) from None

    if entry is None:
        print(f"{COMMAND_NAME}: deleted the registry entry {file}; sbx-add {name} HOST_PATH registers the sandbox again")
    else:
        print(
            f'{COMMAND_NAME}: deleted the registry entry {file}; sbx-add {name} "{entry.path}" '
            "registers the directory again"
        )


# ------------------------------------------------------------------------------
# The command
# ------------------------------------------------------------------------------
# An entry that exists but is unusable is broken: it comes back as None with its
# problem. A missing entry is the not-registered error.
# ------------------------------------------------------------------------------

def _read_entry_or_problem(registry: Path, name: str) -> tuple[Entry | None, SbxError | None]:
    try:
        return read_entry(registry, name), None
    except SbxError as problem:
        if not entry_file(registry, name).is_file():
            raise

        return None, problem


def _remove_sandbox(
    argument_list: list[str],
    environ: Mapping[str, str],
    docker: Docker,
    repo_dir: Path,
    is_terminal: Callable[[], bool],
    read_answer: Callable[[str], str],
) -> None:
    request = _parse_arguments(argument_list)
    registry = registry_dir(config_dir(environ))
    tag = image_tag(environ, COMMAND_NAME)

    check_name(request.name)

    file = entry_file(registry, request.name)
    entry, problem = _read_entry_or_problem(registry, request.name)

    if entry is None:
        dir_text = _BROKEN_DIR_TEXT

        _remove_broken_sandbox(docker, request, file, problem, is_terminal, read_answer)
    else:
        dir_text = entry.path

        _confirm_if_running(docker, request.name, request.skip_confirmation, is_terminal, read_answer)
        _remove_container(docker, entry, tag, repo_dir, environ)

    if request.unregister:
        _unregister_sandbox(file, request.name, entry, dir_text)

    print(f"{COMMAND_NAME}: the container {container_name(request.name)} is gone; nothing in {dir_text} was changed")


def main(
    argument_list: list[str],
    environ: Mapping[str, str] = os.environ,
    docker: Docker = run_docker,
    repo_dir: Path = REPO_DIR,
    is_terminal: Callable[[], bool] = sys.stdin.isatty,
    read_answer: Callable[[str], str] = input,
) -> int:
    return run_command(
        COMMAND_NAME,
        partial(_remove_sandbox, argument_list, environ, docker, repo_dir, is_terminal, read_answer),
    )


# ------------------------------------------------------------------------------
# Main / Entry Point
# ------------------------------------------------------------------------------

if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
