# ------------------------------------------------------------------------------
# sbx-add: registers a sandbox once: its name, its directory on the host, its agent
# ------------------------------------------------------------------------------
# The entry is NAME.json in the sbx config directory, outside every mount. Nothing
# is made until every check has passed.
# ------------------------------------------------------------------------------

import os
import sys
from collections.abc import Mapping
from functools import partial
from pathlib import Path

from sbx.cli import REPO_DIR, SbxError, UsageError, run_command
from sbx.names import KNOWN_AGENT_LIST, check_name, image_tag, is_known_agent
from sbx.overlap import check_host_path, paths_overlap
from sbx.registry import Entry, config_dir, entry_file, list_entry_names, read_entry, registry_dir, write_entry


# ------------------------------------------------------------------------------
# Constants
# ------------------------------------------------------------------------------

COMMAND_NAME = "sbx-add"
_DEFAULT_AGENT = "claude"


# ------------------------------------------------------------------------------
# Refusals
# ------------------------------------------------------------------------------
# A sandbox that reaches the registry could rewrite its own entry; this also
# refuses / and the host home, which hold it. The host runs the tools clone's
# scripts and compose.yml, so a sandbox that reaches them could change what the
# host runs next. Two sandboxes on one directory, or one inside the other, would
# share a state/ directory and its logins; a broken entry stops the check with its
# own error.
# ------------------------------------------------------------------------------

def _refuse_registered(registry: Path, name: str) -> None:
    file = entry_file(registry, name)

    if file.exists():
        raise SbxError(f"{name} is already registered in {file}; nothing was changed")


def _refuse_registry_overlap(new_path: str, config: Path) -> None:
    if paths_overlap(new_path, str(config)):
        raise SbxError(
            f"'{new_path}' overlaps the registry directory {config}; "
            "a sandbox there could change the registry. Pick another directory."
        )


def _refuse_repo_overlap(new_path: str, repo_dir: Path) -> None:
    if paths_overlap(new_path, str(repo_dir)):
        raise SbxError(
            f"'{new_path}' overlaps the tools clone {repo_dir}; "
            "a sandbox there could change the scripts the host runs. Pick another directory."
        )


def _refuse_sandbox_overlap(new_path: str, registry: Path) -> None:
    for other_name in list_entry_names(registry):
        other = read_entry(registry, other_name)

        if paths_overlap(new_path, other.path):
            raise SbxError(
                f"'{new_path}' overlaps the directory of sandbox {other_name} ({other.path}); "
                "each sandbox needs its own directory."
            )


# ------------------------------------------------------------------------------
# Making the directories
# ------------------------------------------------------------------------------

def _create_dirs(new_path: str, name: str) -> None:
    try:
        os.makedirs(f"{new_path}/{name}", exist_ok=True)
        os.makedirs(f"{new_path}/state", exist_ok=True)
    except OSError:
        raise SbxError(f"could not create {new_path}/{name} and {new_path}/state") from None


# ------------------------------------------------------------------------------
# The command
# ------------------------------------------------------------------------------

def _agent_of(argument_list: list[str]) -> str:
    if len(argument_list) == 3:
        return argument_list[2]

    return _DEFAULT_AGENT


def _add_sandbox(argument_list: list[str], environ: Mapping[str, str], repo_dir: Path) -> None:
    usage_text = f"NAME HOST_PATH [{'|'.join(KNOWN_AGENT_LIST)}]"

    if len(argument_list) < 2 or len(argument_list) > 3:
        raise UsageError(usage_text)

    agent = _agent_of(argument_list)

    if not is_known_agent(agent):
        raise UsageError(usage_text)

    name = argument_list[0]
    config = config_dir(environ)
    registry = registry_dir(config)

    image_tag(environ, COMMAND_NAME)
    check_name(name)
    _refuse_registered(registry, name)

    new_path = check_host_path(argument_list[1])

    _refuse_registry_overlap(new_path, config)
    _refuse_repo_overlap(new_path, repo_dir)
    _refuse_sandbox_overlap(new_path, registry)
    _create_dirs(new_path, name)
    write_entry(registry, Entry(name, new_path, agent))

    print(f"{COMMAND_NAME}: registered {name} at {new_path} (agent {agent})")
    print(
        f"{COMMAND_NAME}: next, sbx-upgrade {name} builds the images and starts it; "
        f"sbx-start {name} starts it on the images you have"
    )


def main(argument_list: list[str], environ: Mapping[str, str] = os.environ, repo_dir: Path = REPO_DIR) -> int:
    return run_command(COMMAND_NAME, partial(_add_sandbox, argument_list, environ, repo_dir))


# ------------------------------------------------------------------------------
# Main / Entry Point
# ------------------------------------------------------------------------------

if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
