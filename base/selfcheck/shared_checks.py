# The checks every sandbox image shares. The image puts this file in
# /usr/local/lib/sbx-selfcheck/ and the launcher runs CHECK_LIST first.

import os
import pwd
import tempfile
from pathlib import Path

from sbx_selfcheck import (
    MOUNTINFO_FILE,
    STATE_DIR,
    WORKSPACE_DIR,
    Check,
    CheckResult,
    failed,
    mac_hint,
    passed,
    read_mount_point_set,
    restart_hint,
    sandbox_name,
    shell_hint,
    start_hint,
)

SANDBOX_UID = 1000
SANDBOX_GID = 1000
SANDBOX_USER = "sandbox"
BASE_STATE_DIR_LIST = ["shell", "gh", "git"]
SKIPPED_STATE_DIR_SET = {"cache/npm", "cache/uv", "m2"}
GSD_SYNC_FOLDER_SET = {"gsd-core", "hooks", "scripts"}
REPORTED_PATH_LIMIT = 10
STATE_WRITE_PROBE_PREFIX = ".sbx-selfcheck-"


def user_name_of(uid: int) -> str:
    try:
        return pwd.getpwuid(uid).pw_name
    except KeyError:
        return "unknown"


def user_result(expected_uid: int, expected_gid: int, expected_name: str) -> CheckResult:
    actual_uid = os.getuid()
    actual_gid = os.getgid()
    actual_name = user_name_of(actual_uid)
    actual_text = f"uid {actual_uid}, gid {actual_gid}, name {actual_name}"
    expected_text = f"uid {expected_uid}, gid {expected_gid}, name {expected_name}"

    if actual_text == expected_text:
        return passed(actual_text)

    return failed(
        f"runs as uid {actual_uid}, gid {actual_gid}, name {actual_name}; expected {expected_text}",
        shell_hint(),
    )


def check_user_sandbox() -> CheckResult:
    return user_result(SANDBOX_UID, SANDBOX_GID, SANDBOX_USER)


def workspace_mount_result(
    workspace_dir: Path = WORKSPACE_DIR,
    mountinfo_file: Path = MOUNTINFO_FILE,
) -> CheckResult:
    if str(workspace_dir) not in read_mount_point_set(mountinfo_file):
        return failed(f"{workspace_dir} is not a mount point; its data would be lost on recreate", start_hint())

    if not os.access(workspace_dir, os.W_OK):
        return failed(
            f"{workspace_dir} is not writable by {user_name_of(os.getuid())}",
            mac_hint(
                "make the project folder writable by your Mac user, then restart the sandbox",
                f"sbx-stop {sandbox_name()}, then sbx-start {sandbox_name()}",
            ),
        )

    return passed(f"{workspace_dir} is a writable mount point")


def project_folder_result(workspace_dir: Path, project_name: str) -> CheckResult:
    start_text = mac_hint("start the sandbox with sbx-start, which checks the project folder", f"sbx-start {sandbox_name()}")

    if not project_name:
        return failed("SBX_NAME is not set", start_text)

    project_dir = workspace_dir / project_name

    if not project_dir.is_dir():
        return failed(f"{project_dir} (the project folder) is missing", start_text)

    return passed(f"{project_dir} exists")


def state_folders_result(state_dir: Path, state_dirs_text: str) -> CheckResult:
    folder_list = BASE_STATE_DIR_LIST + state_dirs_text.split()
    missing_list = []

    for folder in folder_list:
        if not (state_dir / folder).is_dir():
            missing_list.append(folder)

    if missing_list:
        return failed(
            f"missing under {state_dir}: {', '.join(missing_list)}",
            restart_hint() + "; the start makes the state folders",
        )

    return passed(f"{', '.join(folder_list)} exist under {state_dir}")


def state_writable_result(state_dir: Path) -> CheckResult:
    try:
        probe_descriptor, probe_name = tempfile.mkstemp(dir=state_dir, prefix=STATE_WRITE_PROBE_PREFIX)
    except OSError as e:
        return failed(
            f"cannot make a file in {state_dir}: {e}",
            mac_hint(
                "make the state folder of the sandbox writable by your Mac user, then restart the sandbox",
                f"sbx-stop {sandbox_name()}, then sbx-start {sandbox_name()}",
            ),
        )

    try:
        os.close(probe_descriptor)
    finally:
        os.remove(probe_name)

    return passed(f"{state_dir} is writable")


def is_tolerated_path(relative_path: Path, tolerated_folder_set: set[str]) -> bool:
    return len(relative_path.parts) >= 2 and relative_path.parts[1] in tolerated_folder_set


def scan_owned_state(
    state_dir: Path,
    owner_uid: int,
    skipped_relative_set: set[str],
    tolerated_folder_set: set[str],
) -> tuple[list[str], int]:
    reported_list = []
    tolerated_count = 0
    pending_dir_list = [state_dir]

    while pending_dir_list:
        current_dir = pending_dir_list.pop()

        with os.scandir(current_dir) as entry_iterator:
            entry_list = list(entry_iterator)

        for entry in entry_list:
            relative_path = Path(entry.path).relative_to(state_dir)

            if relative_path.as_posix() in skipped_relative_set:
                continue

            try:
                entry_stat = entry.stat(follow_symlinks=False)
            except FileNotFoundError:
                continue

            if entry_stat.st_uid == owner_uid:
                if is_tolerated_path(relative_path, tolerated_folder_set):
                    tolerated_count += 1
                else:
                    reported_list.append(relative_path.as_posix())

            if entry.is_dir(follow_symlinks=False):
                pending_dir_list.append(Path(entry.path))

    return sorted(reported_list), tolerated_count


def owned_by_uid_paths(
    state_dir: Path,
    owner_uid: int,
    skipped_relative_set: set[str],
    tolerated_folder_set: set[str],
) -> list[str]:
    return scan_owned_state(state_dir, owner_uid, skipped_relative_set, tolerated_folder_set)[0]


def root_owned_state_result(state_dir: Path, owner_uid: int) -> CheckResult:
    reported_list, tolerated_count = scan_owned_state(state_dir, owner_uid, SKIPPED_STATE_DIR_SET, GSD_SYNC_FOLDER_SET)

    if not reported_list:
        return passed(f"no root-owned path under state/ outside the GSD sync folders ({tolerated_count} tolerated)")

    return failed(
        f"{len(reported_list)} paths under state/ are owned by uid {owner_uid}: "
        + ", ".join(reported_list[:REPORTED_PATH_LIMIT]),
        "give them back to the sandbox user: in this sandbox run: chown -R sandbox:sandbox /home/sandbox/workspace/state",
    )


def check_workspace_mount() -> CheckResult:
    return workspace_mount_result()


def check_project_folder() -> CheckResult:
    return project_folder_result(WORKSPACE_DIR, os.environ.get("SBX_NAME", ""))


def check_state_folders() -> CheckResult:
    return state_folders_result(STATE_DIR, os.environ.get("SBX_STATE_DIRS", ""))


def check_state_writable() -> CheckResult:
    return state_writable_result(STATE_DIR)


def check_no_root_owned_state() -> CheckResult:
    return root_owned_state_result(STATE_DIR, 0)


CHECK_LIST = [
    Check("workspace-mount", check_workspace_mount),
    Check("project-folder", check_project_folder),
    Check("state-folders", check_state_folders),
    Check("state-writable", check_state_writable),
    Check("no-root-owned-state", check_no_root_owned_state),
    Check("user-sandbox", check_user_sandbox),
]
