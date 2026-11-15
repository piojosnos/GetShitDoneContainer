# ------------------------------------------------------------------------------
# The folders and commands the image ships
# ------------------------------------------------------------------------------
# The roots of the base image, shared by the checks that walk them. Each agent
# keeps the roots it adds in its own library. The image puts this file in
# /usr/local/lib/sbx-selfcheck/.
# ------------------------------------------------------------------------------

from pathlib import Path

COMMAND_DIR = Path("/usr/local/bin")
COMMAND_PREFIX = "sbx-"
HOOK_DIR = Path("/etc/sbx/start.d")
LAUNCHER_FILE = Path("/usr/local/lib/sbx-selfcheck/sbx-selfcheck")
BASE_FOLDER_LIST = [Path("/usr/local/lib/sbx-selfcheck"), Path("/etc/sbx")]


# ------------------------------------------------------------------------------
# The roots of the base image
# ------------------------------------------------------------------------------
# The sbx commands are roots of their own because /usr/local/bin also holds the
# tools of the toolchains.
# ------------------------------------------------------------------------------

def sbx_command_list(command_dir: Path = COMMAND_DIR) -> list[Path]:
    return sorted(command_dir.glob(COMMAND_PREFIX + "*"))


def base_root_list(command_dir: Path = COMMAND_DIR) -> list[Path]:
    return BASE_FOLDER_LIST + sbx_command_list(command_dir)
