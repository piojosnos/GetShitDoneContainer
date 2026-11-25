# --------------------------------------------------------------------------------
# The paths of the sandbox and small path helpers
# --------------------------------------------------------------------------------
# The image puts this file in /usr/local/lib/sbx-selfcheck/.
# --------------------------------------------------------------------------------

from pathlib import Path

HOME_DIR = Path("/home/sandbox")
WORKSPACE_DIR = HOME_DIR / "workspace"
STATE_DIR = WORKSPACE_DIR / "state"
BEST_PRACTICES_DIR = WORKSPACE_DIR / "best-practices"
VERSIONS_FILE = Path("/etc/sbx/versions.env")
TOOL_VERSIONS_FILE = Path("/etc/sbx/tool-versions")
BASE_STATE_DIR_LIST = ["shell", "gh", "git"]
AGENT_STEPS_DIR = Path("/etc/sbx/init.d")
INIT_MARKER_FILE = HOME_DIR / ".sbx-init-done"
INIT_LOCK_FILE = HOME_DIR / ".sbx-init.lock"
AGENT_BIN_DIR = Path("/opt/sbx/agents/bin")


# --------------------------------------------------------------------------------
# Path helpers
# --------------------------------------------------------------------------------

def path_is_present(path: Path) -> bool:
    return path.is_symlink() or path.exists()


def is_under(path_text: str, root_text: str) -> bool:
    return path_text == root_text or path_text.startswith(root_text + "/")


def link_text(link: Path) -> str | None:
    try:
        return str(link.readlink())
    except OSError:
        return None


def state_dir_name_list(state_dirs_text: str) -> list[str]:
    name_list = []

    for name in BASE_STATE_DIR_LIST + state_dirs_text.split():
        if name not in name_list:
            name_list.append(name)

    return name_list
