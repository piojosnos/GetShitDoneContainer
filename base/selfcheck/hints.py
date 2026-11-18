# ------------------------------------------------------------------------------
# The fix hints
# ------------------------------------------------------------------------------
# Every hint that tells the user to run a command on the Mac names the sandbox
# from SBX_NAME. The image puts this file in /usr/local/lib/sbx-selfcheck/.
# ------------------------------------------------------------------------------

import os
from typing import Mapping

_UNSET_SANDBOX_NAME = "NAME"


# ------------------------------------------------------------------------------
# Sandbox name and hints
# ------------------------------------------------------------------------------

def sandbox_name(environment_map: Mapping[str, str] = os.environ) -> str:
    name = environment_map.get("SBX_NAME", "")

    if not name:
        return _UNSET_SANDBOX_NAME

    return name


def mac_hint(action_text: str, command_text: str) -> str:
    return f"{action_text}: on the Mac run: {command_text}"


def rebuild_hint(environment_map: Mapping[str, str] = os.environ) -> str:
    return mac_hint("rebuild the image and recreate the sandbox", f"sbx-upgrade {sandbox_name(environment_map)}")


def restart_hint(environment_map: Mapping[str, str] = os.environ) -> str:
    name = sandbox_name(environment_map)

    return mac_hint("restart the sandbox", f"sbx-stop {name}, then sbx-start {name}")


def start_hint(environment_map: Mapping[str, str] = os.environ) -> str:
    name = sandbox_name(environment_map)

    return mac_hint("run sbx-selfcheck in a sandbox started with sbx-start", f"sbx-start {name}, then sbx-shell {name}")


def shell_hint(environment_map: Mapping[str, str] = os.environ) -> str:
    return mac_hint("open the sandbox shell with sbx-shell", f"sbx-shell {sandbox_name(environment_map)}")


def init_hint(environment_map: Mapping[str, str] = os.environ) -> str:
    return f"run sbx-init in the sandbox shell; on the Mac, sbx-shell {sandbox_name(environment_map)} opens it"


def state_writable_hint() -> str:
    return "make the state folder of the sandbox writable by your Mac user, then run sbx-init again"
