# ------------------------------------------------------------------------------
# The shared checks of the sandbox itself
# ------------------------------------------------------------------------------
# User, workspace mount, state folders, home, git and architecture. The image
# puts this file in /usr/local/lib/sbx-selfcheck/.
# ------------------------------------------------------------------------------

import os
import platform
import pwd
import stat
import tempfile
from dataclasses import dataclass
from pathlib import Path
from typing import Callable, Mapping

from selfcheck_core import (
    ELF_MACHINE_BY_UNAME_MAP,
    HOME_DIR,
    MOUNTINFO_FILE,
    STATE_DIR,
    WORKSPACE_DIR,
    Check,
    CheckResult,
    failed,
    mac_hint,
    passed,
    problem_list_result,
    read_mount_point_set,
    rebuild_hint,
    restart_hint,
    run_command,
    sandbox_name,
    shell_hint,
    start_hint,
)


# ------------------------------------------------------------------------------
# Constants
# ------------------------------------------------------------------------------

_SANDBOX_UID = 1000
_SANDBOX_GID = 1000
_OWNER_FIX_IMAGE = "sbx-base:local"
_SANDBOX_USER = "sandbox"
_BASE_STATE_DIR_LIST = ["shell", "gh", "git"]
_SKIPPED_STATE_DIR_SET = {"cache/npm", "cache/uv", "m2"}
_GSD_SYNC_FOLDER_SET = {"gsd-core", "hooks", "scripts"}
_REPORTED_PATH_LIMIT = 10
_UNREADABLE_SUFFIX = " (unreadable)"
_STATE_WRITE_PROBE_PREFIX = ".sbx-selfcheck-"


# ------------------------------------------------------------------------------
# User and workspace checks
# ------------------------------------------------------------------------------

def _user_name_of(uid: int) -> str:
    try:
        return pwd.getpwuid(uid).pw_name
    except KeyError:
        return "unknown"


def _user_result(expected_uid: int, expected_gid: int, expected_name: str) -> CheckResult:
    actual_uid = os.getuid()
    actual_gid = os.getgid()
    actual_name = _user_name_of(actual_uid)
    actual_text = f"uid {actual_uid}, gid {actual_gid}, name {actual_name}"
    expected_text = f"uid {expected_uid}, gid {expected_gid}, name {expected_name}"

    if actual_text == expected_text:
        return passed(actual_text)

    return failed(
        f"runs as uid {actual_uid}, gid {actual_gid}, name {actual_name}; expected {expected_text}",
        shell_hint(),
    )


def _check_user_sandbox() -> CheckResult:
    return _user_result(_SANDBOX_UID, _SANDBOX_GID, _SANDBOX_USER)


def workspace_mount_result(
    workspace_dir: Path = WORKSPACE_DIR,
    mountinfo_file: Path = MOUNTINFO_FILE,
) -> CheckResult:
    if str(workspace_dir) not in read_mount_point_set(mountinfo_file):
        return failed(f"{workspace_dir} is not a mount point; its data would be lost on recreate", start_hint())

    if not os.access(workspace_dir, os.W_OK):
        return failed(
            f"{workspace_dir} is not writable by {_user_name_of(os.getuid())}",
            "make the project folder writable by your Mac user, then " + restart_hint(),
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


# ------------------------------------------------------------------------------
# State folder checks
# ------------------------------------------------------------------------------

def state_folders_result(state_dir: Path, state_dirs_text: str) -> CheckResult:
    folder_list = _BASE_STATE_DIR_LIST + state_dirs_text.split()
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
        probe_descriptor, probe_name = tempfile.mkstemp(dir=state_dir, prefix=_STATE_WRITE_PROBE_PREFIX)
    except OSError as e:
        return failed(
            f"cannot make a file in {state_dir}: {e}",
            "make the state folder of the sandbox writable by your Mac user, then " + restart_hint(),
        )

    try:
        os.close(probe_descriptor)
    finally:
        Path(probe_name).unlink()

    return passed(f"{state_dir} is writable")


@dataclass(frozen=True)
class _ScanRules:
    state_dir: Path
    owner_uid: int
    skipped_relative_set: set[str]
    tolerated_folder_set: set[str]


def _is_tolerated_path(relative_path: Path, tolerated_folder_set: set[str]) -> bool:
    return len(relative_path.parts) >= 2 and relative_path.parts[1] in tolerated_folder_set


def _mark_unreadable_folder(reported_list: list[str], relative_dir: Path, tolerated_folder_set: set[str]) -> None:
    if _is_tolerated_path(relative_dir, tolerated_folder_set):
        return

    if relative_dir.as_posix() in reported_list:
        reported_list.remove(relative_dir.as_posix())

    reported_list.append(relative_dir.as_posix() + _UNREADABLE_SUFFIX)


def _read_entry_list(folder: Path) -> list[Path]:
    return list(folder.iterdir())


def _entry_list_or_none(
    current_dir: Path,
    rules: _ScanRules,
    entry_reader: Callable[[Path], list[Path]],
    reported_list: list[str],
) -> list[Path] | None:
    try:
        return entry_reader(current_dir)
    except FileNotFoundError:
        return None
    except OSError:
        relative_dir = current_dir.relative_to(rules.state_dir)
        _mark_unreadable_folder(reported_list, relative_dir, rules.tolerated_folder_set)

        return None


def _scan_entry_list(
    entry_list: list[Path],
    current_dir: Path,
    rules: _ScanRules,
    reported_list: list[str],
    pending_dir_list: list[Path],
) -> int:
    tolerated_count = 0

    for entry in entry_list:
        relative_path = entry.relative_to(rules.state_dir)

        if relative_path.as_posix() in rules.skipped_relative_set:
            continue

        try:
            entry_stat = entry.lstat()
        except FileNotFoundError:
            continue
        except PermissionError:
            # An entry stat needs search permission on its folder, so every other entry would fail the same way.
            relative_dir = current_dir.relative_to(rules.state_dir)
            _mark_unreadable_folder(reported_list, relative_dir, rules.tolerated_folder_set)
            break

        if entry_stat.st_uid == rules.owner_uid:
            if _is_tolerated_path(relative_path, rules.tolerated_folder_set):
                tolerated_count += 1
            else:
                reported_list.append(relative_path.as_posix())

        if stat.S_ISDIR(entry_stat.st_mode):
            pending_dir_list.append(entry)

    return tolerated_count


def scan_owned_state(
    state_dir: Path,
    owner_uid: int,
    skipped_relative_set: set[str],
    tolerated_folder_set: set[str],
    entry_reader: Callable[[Path], list[Path]] = _read_entry_list,
) -> tuple[list[str], int]:
    rules = _ScanRules(state_dir, owner_uid, skipped_relative_set, tolerated_folder_set)
    reported_list = []
    tolerated_count = 0
    pending_dir_list = [state_dir]

    while pending_dir_list:
        current_dir = pending_dir_list.pop()
        entry_list = _entry_list_or_none(current_dir, rules, entry_reader, reported_list)

        if entry_list is None:
            continue

        tolerated_count += _scan_entry_list(entry_list, current_dir, rules, reported_list, pending_dir_list)

    return sorted(reported_list), tolerated_count


def _owner_fix_hint(state_dir: Path, environment_map: Mapping[str, str] = os.environ) -> str:
    return mac_hint(
        "give the paths back to the sandbox user from a throwaway root container, "
        "since the sandbox cannot change owners",
        "docker run --rm --network none -u root --entrypoint chown "
        f"--volumes-from sbx-{sandbox_name(environment_map)} {_OWNER_FIX_IMAGE} -R {_SANDBOX_UID}:{_SANDBOX_GID} {state_dir}",
    )


def root_owned_state_result(
    state_dir: Path,
    owner_uid: int,
    environment_map: Mapping[str, str] = os.environ,
) -> CheckResult:
    reported_list, tolerated_count = scan_owned_state(state_dir, owner_uid, _SKIPPED_STATE_DIR_SET, _GSD_SYNC_FOLDER_SET)

    if not reported_list:
        return passed(f"no root-owned path under state/ outside the GSD sync folders ({tolerated_count} tolerated)")

    return failed(
        f"{len(reported_list)} paths under state/ are owned by uid {owner_uid} or unreadable: "
        + ", ".join(reported_list[:_REPORTED_PATH_LIMIT]),
        _owner_fix_hint(state_dir, environment_map),
    )


# ------------------------------------------------------------------------------
# Home checks
# ------------------------------------------------------------------------------

def home_layout_result(home_dir: Path = HOME_DIR) -> CheckResult:
    missing_list = []

    for name in [".bashrc", ".local"]:
        if not (home_dir / name).exists():
            missing_list.append(name)

    if missing_list:
        return failed(f"missing in {home_dir}: {', '.join(missing_list)}", rebuild_hint())

    return passed(f".bashrc and .local exist in {home_dir}")


def _owner_name_of_path(path: Path) -> str:
    return _user_name_of(path.stat().st_uid)


def owned_by_result(path_list: list[Path], owner_name: str) -> CheckResult:
    problem_list = []

    for path in path_list:
        if not path.exists():
            problem_list.append(f"{path} is missing")
            continue

        actual_owner = _owner_name_of_path(path)

        if actual_owner != owner_name:
            problem_list.append(f"{path} is owned by {actual_owner}, expected {owner_name}")

    return problem_list_result(problem_list, rebuild_hint(), f"{len(path_list)} paths are owned by {owner_name}")


# ------------------------------------------------------------------------------
# Git checks
# ------------------------------------------------------------------------------

def safe_directory_result(environment_map: Mapping[str, str] = os.environ) -> CheckResult:
    completed = run_command(["git", "config", "--system", "--get-all", "safe.directory"], environment_map)

    for line in completed.stdout.splitlines():
        if line.strip() == "*":
            return passed("git trusts every folder (safe.directory is *)")

    return failed("the system git config does not set safe.directory to *", rebuild_hint())


def git_identity_result(environment_map: Mapping[str, str] = os.environ) -> CheckResult:
    empty_list = []

    for key in ["user.name", "user.email"]:
        completed = run_command(["git", "config", "--global", key], environment_map)

        if not completed.stdout.strip():
            empty_list.append(key)

    if empty_list:
        return failed(
            f"{' and '.join(empty_list)} not set in the global git config",
            "run sbx-gh-login in this sandbox; it asks for the name and email",
        )

    return passed("user.name and user.email are set")


# ------------------------------------------------------------------------------
# Architecture check
# ------------------------------------------------------------------------------

def architecture_result() -> CheckResult:
    machine = platform.machine()

    if machine not in ELF_MACHINE_BY_UNAME_MAP:
        return failed(f"the machine is {machine}; the images are built for aarch64 or x86_64", rebuild_hint())

    return passed(f"{machine}, ELF machine 0x{ELF_MACHINE_BY_UNAME_MAP[machine]:02X}")


# ------------------------------------------------------------------------------
# Check entries
# ------------------------------------------------------------------------------

def _check_workspace_mount() -> CheckResult:
    return workspace_mount_result()


def _check_project_folder() -> CheckResult:
    return project_folder_result(WORKSPACE_DIR, os.environ.get("SBX_NAME", ""))


def _check_state_folders() -> CheckResult:
    return state_folders_result(STATE_DIR, os.environ.get("SBX_STATE_DIRS", ""))


def _check_state_writable() -> CheckResult:
    return state_writable_result(STATE_DIR)


def _check_no_root_owned_state() -> CheckResult:
    return root_owned_state_result(STATE_DIR, 0)


def _check_home_layout() -> CheckResult:
    return home_layout_result()


def _check_home_owners() -> CheckResult:
    return owned_by_result([HOME_DIR / ".local", HOME_DIR / ".local" / "state"], _SANDBOX_USER)


def _check_git_safe_directory() -> CheckResult:
    return safe_directory_result()


def _check_git_identity() -> CheckResult:
    return git_identity_result()


def _check_architecture() -> CheckResult:
    return architecture_result()


SANDBOX_CHECK_LIST = [
    Check("workspace-mount", _check_workspace_mount),
    Check("project-folder", _check_project_folder),
    Check("state-folders", _check_state_folders),
    Check("state-writable", _check_state_writable),
    Check("no-root-owned-state", _check_no_root_owned_state),
    Check("user-sandbox", _check_user_sandbox),
    Check("home-layout", _check_home_layout),
    Check("home-owners", _check_home_owners),
    Check("architecture", _check_architecture),
    Check("git-safe-directory", _check_git_safe_directory),
    Check("git-identity", _check_git_identity),
]
