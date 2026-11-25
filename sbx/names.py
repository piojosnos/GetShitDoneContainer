# --------------------------------------------------------------------------------
# The names the sbx commands accept: sandbox name, agent, image tag, images
# --------------------------------------------------------------------------------
# Compose lowercases a project name, so two names that differ only in case
# would share one project; the name rule allows lowercase only.
# --------------------------------------------------------------------------------

import re
from collections.abc import Mapping

from sbx.cli import SbxError, print_notice


# --------------------------------------------------------------------------------
# Constants
# --------------------------------------------------------------------------------

KNOWN_AGENT_LIST = ["claude", "cursor"]
KNOWN_IMAGE_TAG_LIST = ["local", "test"]
RESERVED_NAME_LIST = ["state", "best-practices"]
NAME_RULE_PATTERN = re.compile(r"[a-z][a-z0-9-]{0,30}", re.ASCII)
NAME_RULE_TEXT = "starts with a lowercase letter, then lowercase letters, digits or hyphens, 31 characters at most"
_DEFAULT_IMAGE_TAG = "local"


# --------------------------------------------------------------------------------
# The sandbox name
# --------------------------------------------------------------------------------
# fullmatch sees the whole name, so a trailing line break or a second line fails.
# --------------------------------------------------------------------------------

def check_name(name: str) -> None:
    if NAME_RULE_PATTERN.fullmatch(name) is None:
        raise SbxError(f"'{name}' breaks the sandbox name rule: {NAME_RULE_TEXT}. Example: my-project.")

    for reserved_name in RESERVED_NAME_LIST:
        if name == reserved_name:
            raise SbxError(
                f"'{name}' is taken: the sandbox directory uses {reserved_name}/ itself. Pick another name."
            )


# --------------------------------------------------------------------------------
# The agent
# --------------------------------------------------------------------------------

def is_known_agent(agent: str) -> bool:
    return agent in KNOWN_AGENT_LIST


# --------------------------------------------------------------------------------
# The image tag and the image names
# --------------------------------------------------------------------------------
# Unset or empty means local, as in compose.yml and build.sh. A tag other than
# local is named on stderr, so a value left in the shell never moves a real
# sandbox onto other images unseen.
# --------------------------------------------------------------------------------

def image_tag(environ: Mapping[str, str], command_name: str) -> str:
    tag = environ.get("SBX_IMAGE_TAG", "") or _DEFAULT_IMAGE_TAG

    if tag not in KNOWN_IMAGE_TAG_LIST:
        raise SbxError(f"SBX_IMAGE_TAG must be {' or '.join(KNOWN_IMAGE_TAG_LIST)}, not '{tag}'")

    if tag != _DEFAULT_IMAGE_TAG:
        print_notice(
            command_name,
            f"using the {tag} images because SBX_IMAGE_TAG={tag}; unset it to use the local images your sandboxes run",
        )

    return tag


def agent_image(agent: str, tag: str) -> str:
    return f"sbx-{agent}:{tag}"


def base_image(tag: str) -> str:
    return f"sbx-base:{tag}"


def container_name(name: str) -> str:
    return f"sbx-{name}"
