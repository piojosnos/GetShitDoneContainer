# --------------------------------------------------------------------------------
# sbx-migrate-registry: writes NAME.json next to each old KEY=value entry
# --------------------------------------------------------------------------------
# A one-off. It is the only code that knows the old format. It leaves every old
# file as it was, and it never overwrites a NAME.json.
# --------------------------------------------------------------------------------

import os
import sys
from collections.abc import Mapping
from functools import partial
from pathlib import Path

from sbx.cli import SbxError, UsageError, run_command
from sbx.docker import Docker, run_docker
from sbx.names import KNOWN_AGENT_LIST, check_name, image_tag, is_known_agent
from sbx.registry import Entry, config_dir, entry_file, registry_dir, write_entry


# --------------------------------------------------------------------------------
# Constants
# --------------------------------------------------------------------------------

COMMAND_NAME = "sbx-migrate-registry"
_DIR_KEY = "SBX_DIR="
_AGENT_KEY = "SBX_AGENT="
_CONVERTED = "converted"
_DONE = "done"
_FAILED = "failed"
_LEFT_IN_PLACE_TEXT = "the old files are left in place and can be deleted once each sandbox starts"


# --------------------------------------------------------------------------------
# The old format
# --------------------------------------------------------------------------------
# Lines of text; the last SBX_DIR= and the last SBX_AGENT= win. A value is never
# executed or expanded, so $(command) is only a path that does not exist.
# --------------------------------------------------------------------------------

def _read_old_entry(file: Path) -> tuple[str, str]:
    text = file.read_text(encoding="utf-8")
    path = ""
    agent = ""

    for line in text.split("\n"):
        if line.startswith(_DIR_KEY):
            path = line[len(_DIR_KEY):]
        elif line.startswith(_AGENT_KEY):
            agent = line[len(_AGENT_KEY):]

    return path, agent


# --------------------------------------------------------------------------------

def _old_file_list(registry: Path) -> list[Path]:
    if not registry.is_dir():
        return []

    file_list = []

    for file in registry.iterdir():
        if file.name.startswith(".") or file.name.endswith(".json") or not file.is_file():
            continue

        file_list.append(file)

    return sorted(file_list)


# --------------------------------------------------------------------------------
# Converting one file
# --------------------------------------------------------------------------------

def _say(name: str, text: str) -> None:
    print(f"{COMMAND_NAME}: {name}: {text}")


# --------------------------------------------------------------------------------

def _not_converted(name: str, reason: str) -> str:
    _say(name, f"not converted: {reason}")

    return _FAILED


# --------------------------------------------------------------------------------

def _problem_of(name: str, path: str, agent: str) -> str:
    try:
        check_name(name)
    except SbxError as e:
        return str(e)

    if not path.startswith("/"):
        return "no absolute SBX_DIR"

    if not is_known_agent(agent):
        return f"agent '{agent}' is not one of: {' '.join(KNOWN_AGENT_LIST)}"

    return ""


# --------------------------------------------------------------------------------

def _convert_one(registry: Path, file: Path) -> str:
    name = file.name

    if entry_file(registry, name).exists():
        _say(name, f"{name}.json exists; left as it is")

        return _DONE

    try:
        path, agent = _read_old_entry(file)
    except (OSError, UnicodeDecodeError):
        return _not_converted(name, f"cannot read {file}")

    problem = _problem_of(name, path, agent)

    if problem:
        return _not_converted(name, problem)

    try:
        write_entry(registry, Entry(name, path, agent))
    except SbxError as e:
        return _not_converted(name, str(e))

    _say(name, f"wrote {name}.json (path {path}, agent {agent})")

    return _CONVERTED


# --------------------------------------------------------------------------------
# The command
# --------------------------------------------------------------------------------

def _migrate(argument_list: list[str], environ: Mapping[str, str]) -> None:
    if argument_list:
        raise UsageError("")

    registry = registry_dir(config_dir(environ))
    image_tag(environ, COMMAND_NAME)
    file_list = _old_file_list(registry)

    if not file_list:
        print(f"{COMMAND_NAME}: no old registry entries in {registry}")

        return

    outcome_list = []

    for file in file_list:
        outcome_list.append(_convert_one(registry, file))

    failed_count = outcome_list.count(_FAILED)
    print(
        f"{COMMAND_NAME}: {outcome_list.count(_CONVERTED)} converted, {outcome_list.count(_DONE)} already done, "
        f"{failed_count} not converted; {_LEFT_IN_PLACE_TEXT}"
    )

    if failed_count > 0:
        raise SbxError(f"{failed_count} not converted; see the lines above")


# --------------------------------------------------------------------------------

def main(argument_list: list[str], environ: Mapping[str, str] = os.environ, docker: Docker = run_docker) -> int:
    return run_command(COMMAND_NAME, partial(_migrate, argument_list, environ))


# --------------------------------------------------------------------------------
# Main / Entry Point
# --------------------------------------------------------------------------------

if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
