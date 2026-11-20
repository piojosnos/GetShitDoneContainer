# ------------------------------------------------------------------------------
# The registry: one NAME.json file per sandbox under the sbx config directory
# ------------------------------------------------------------------------------
# An entry is data. The file is parsed as JSON and never executed or expanded,
# so a value such as $(command) is only a path that does not exist.
# ------------------------------------------------------------------------------

import json
from collections.abc import Mapping
from dataclasses import dataclass
from pathlib import Path

from sbx.cli import SbxError
from sbx.names import KNOWN_AGENT_LIST, is_known_agent


# ------------------------------------------------------------------------------
# Constants
# ------------------------------------------------------------------------------

_ENTRY_SUFFIX = ".json"


# ------------------------------------------------------------------------------
# Entry
# ------------------------------------------------------------------------------

@dataclass(frozen=True)
class Entry:
    name: str
    path: str
    agent: str


# ------------------------------------------------------------------------------
# Where the registry is
# ------------------------------------------------------------------------------

def config_dir(environ: Mapping[str, str]) -> Path:
    configured = environ.get("SBX_CONFIG_DIR", "")

    if not configured:
        home = environ.get("HOME", "")

        if not home:
            raise SbxError("HOME and SBX_CONFIG_DIR are both empty; set SBX_CONFIG_DIR to an absolute path")

        configured = f"{home}/.config/sbx"

    if not configured.startswith("/"):
        raise SbxError(f"SBX_CONFIG_DIR must be an absolute path, not '{configured}'")

    return Path(configured)


def registry_dir(config: Path) -> Path:
    return config / "sandboxes"


def entry_file(registry: Path, name: str) -> Path:
    return registry / f"{name}{_ENTRY_SUFFIX}"


# ------------------------------------------------------------------------------
# Reading
# ------------------------------------------------------------------------------
# The caller checked the name. Extra keys in a file are ignored.
# ------------------------------------------------------------------------------

def _load_object(file: Path) -> dict:
    try:
        text = file.read_text(encoding="utf-8")
    except OSError:
        raise SbxError(f"cannot read {file}") from None
    except UnicodeDecodeError:
        raise SbxError(f"the entry {file} is not a JSON object") from None

    try:
        data = json.loads(text)
    except ValueError:
        raise SbxError(f"the entry {file} is not a JSON object") from None

    if not isinstance(data, dict):
        raise SbxError(f"the entry {file} is not a JSON object")

    return data


def read_entry(registry: Path, name: str) -> Entry:
    file = entry_file(registry, name)

    if not file.is_file():
        raise SbxError(f"{name} is not registered; run: sbx-add {name} HOST_PATH")

    data = _load_object(file)
    path = data.get("path")

    if not isinstance(path, str) or not path.startswith("/"):
        raise SbxError(f"the entry {file} has no absolute path")

    agent = data.get("agent")

    if not isinstance(agent, str) or not is_known_agent(agent):
        agent_text = agent if isinstance(agent, str) else ""

        raise SbxError(
            f"the entry {file} names agent '{agent_text}'; the known agents are: {' '.join(KNOWN_AGENT_LIST)}"
        )

    return Entry(name, path, agent)


# ------------------------------------------------------------------------------
# Writing
# ------------------------------------------------------------------------------
# The file is created exclusively, so an existing entry is never overwritten and
# a second sbx-add of one name at the same time is refused. The path is stored as
# given; nothing here resolves it.
# ------------------------------------------------------------------------------

def write_entry(registry: Path, entry: Entry) -> None:
    file = entry_file(registry, entry.name)
    text = json.dumps({"path": entry.path, "agent": entry.agent}, indent=2) + "\n"

    try:
        registry.mkdir(parents=True, exist_ok=True)

        with open(file, "x", encoding="utf-8") as handle:
            handle.write(text)
    except OSError:
        raise SbxError(f"could not write {file}; nothing was registered") from None


# ------------------------------------------------------------------------------
# Listing
# ------------------------------------------------------------------------------
# Only regular NAME.json files count, so an older file without the suffix is
# never looked at. sorted() puts the names in the order of their UTF-8 bytes,
# which is the order of their code points.
# ------------------------------------------------------------------------------

def list_entry_names(registry: Path) -> list[str]:
    if not registry.is_dir():
        return []

    name_list = []

    for file in registry.iterdir():
        if not file.name.endswith(_ENTRY_SUFFIX) or not file.is_file():
            continue

        name = file.name[: -len(_ENTRY_SUFFIX)]

        if name:
            name_list.append(name)

    return sorted(name_list)
