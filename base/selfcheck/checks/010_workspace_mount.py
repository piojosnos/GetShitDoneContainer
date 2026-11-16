# ------------------------------------------------------------------------------
# Check: the workspace is a writable mount
# ------------------------------------------------------------------------------
# The image puts this file in /usr/local/lib/sbx-selfcheck/checks/.
# ------------------------------------------------------------------------------

import os
from pathlib import Path

from check_result import Check, CheckResult, failed, passed
from hints import restart_hint, start_hint
from mounts import MOUNTINFO_FILE, read_mount_point_set
from paths import WORKSPACE_DIR
from users import user_name_of


# ------------------------------------------------------------------------------
# Workspace mount
# ------------------------------------------------------------------------------

def workspace_mount_result(
    workspace_dir: Path = WORKSPACE_DIR,
    mountinfo_file: Path = MOUNTINFO_FILE,
) -> CheckResult:
    if str(workspace_dir) not in read_mount_point_set(mountinfo_file):
        return failed(f"{workspace_dir} is not a mount point; its data would be lost on recreate", start_hint())

    if not os.access(workspace_dir, os.W_OK):
        return failed(
            f"{workspace_dir} is not writable by {user_name_of(os.getuid())}",
            "make the project folder writable by your Mac user, then " + restart_hint(),
        )

    return passed(f"{workspace_dir} is a writable mount point")


# ------------------------------------------------------------------------------
# Check entries
# ------------------------------------------------------------------------------

def _check_workspace_mount() -> CheckResult:
    return workspace_mount_result()


CHECK_LIST = [Check("workspace-mount", _check_workspace_mount)]
