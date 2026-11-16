# ------------------------------------------------------------------------------
# The paths of the sandbox and small path helpers
# ------------------------------------------------------------------------------
# The image puts this file in /usr/local/lib/sbx-selfcheck/.
# ------------------------------------------------------------------------------

from pathlib import Path

HOME_DIR = Path("/home/sandbox")
WORKSPACE_DIR = HOME_DIR / "workspace"
STATE_DIR = WORKSPACE_DIR / "state"
BUNDLE_DIR = WORKSPACE_DIR / "best-practices"
VERSIONS_FILE = Path("/etc/sbx/versions.env")
TOOL_VERSIONS_FILE = Path("/etc/sbx/tool-versions")


# ------------------------------------------------------------------------------
# Path helpers
# ------------------------------------------------------------------------------

def path_is_present(path: Path) -> bool:
    return path.is_symlink() or path.exists()


def is_under(path_text: str, root_text: str) -> bool:
    return path_text == root_text or path_text.startswith(root_text + "/")


def link_text(link: Path) -> str | None:
    try:
        return str(link.readlink())
    except OSError:
        return None
