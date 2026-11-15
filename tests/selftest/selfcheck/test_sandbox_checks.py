# ------------------------------------------------------------------------------
# Tests of the shared sandbox checks
# ------------------------------------------------------------------------------
# They run the logic on real files, real permissions and the real git, inside
# tmp_path.
# ------------------------------------------------------------------------------

import errno
import os
import platform
import subprocess
from pathlib import Path

import pytest

import checks_sandbox
import sbx_selfcheck
import selfcheck_core

CURRENT_USER = checks_sandbox.user_name_of(os.getuid())
NAMED_ENVIRONMENT = {"SBX_NAME": "name1"}
ROOT_MOUNT_LINE = "1 0 8:1 / / rw - ext4 /dev/sda1 rw"
MOUNT_LINE_TEMPLATE = "{number} 1 8:2 / {mount_point} rw,noatime - ext4 /dev/sda2 rw"


def write_mountinfo(mountinfo_file: Path, mount_point_list: list[str]) -> None:
    line_list = [ROOT_MOUNT_LINE]

    for index, mount_point in enumerate(mount_point_list):
        line_list.append(MOUNT_LINE_TEMPLATE.format(number=index + 2, mount_point=mount_point))

    mountinfo_file.write_text("\n".join(line_list) + "\n")


def write_file(path: Path, text: str = "text1") -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(text)


@pytest.fixture
def state_tree(tmp_path):
    state1 = tmp_path / "state1"
    outside1 = tmp_path / "outside1"
    write_file(state1 / "sub1" / "notes1")
    write_file(state1 / "sub1" / "gsd-core" / "file1")
    write_file(state1 / "sub1" / "gsd-core" / "deeper1" / "file2")
    write_file(state1 / "cache" / "npm" / "file3")
    write_file(outside1 / "file4")
    (state1 / "sub1" / "link1").symlink_to(outside1)

    return state1


# ------------------------------------------------------------------------------
# Workspace and project folder checks
# ------------------------------------------------------------------------------

def test_workspace_mount_passes_when_listed_and_writable(tmp_path):
    workspace1 = tmp_path / "workspace1"
    workspace1.mkdir()
    mountinfo1 = tmp_path / "mountinfo1"
    write_mountinfo(mountinfo1, [str(workspace1)])

    result = checks_sandbox.workspace_mount_result(workspace1, mountinfo1)

    assert result.passed
    assert str(workspace1) in result.detail


def test_workspace_mount_fails_with_the_start_hint_when_not_listed(tmp_path):
    workspace1 = tmp_path / "workspace1"
    workspace1.mkdir()
    mountinfo1 = tmp_path / "mountinfo1"
    write_mountinfo(mountinfo1, ["/mount1"])

    result = checks_sandbox.workspace_mount_result(workspace1, mountinfo1)

    assert not result.passed
    assert "in a sandbox started with sbx-start" in result.hint
    assert result.hint == selfcheck_core.start_hint()


@pytest.mark.skipif(os.getuid() == 0, reason="root can write to a read-only folder")
def test_workspace_mount_fails_when_the_folder_is_not_writable(tmp_path, restorable_mode):
    workspace1 = tmp_path / "workspace1"
    workspace1.mkdir()
    mountinfo1 = tmp_path / "mountinfo1"
    write_mountinfo(mountinfo1, [str(workspace1)])
    restorable_mode(workspace1, 0o555)

    result = checks_sandbox.workspace_mount_result(workspace1, mountinfo1)

    assert not result.passed
    assert "not writable" in result.detail
    assert "on the Mac run:" in result.hint


def test_project_folder_passes_when_the_folder_exists(tmp_path):
    (tmp_path / "name1").mkdir()

    result = checks_sandbox.project_folder_result(tmp_path, "name1")

    assert result.passed
    assert str(tmp_path / "name1") in result.detail


def test_project_folder_fails_naming_the_missing_path(tmp_path):
    result = checks_sandbox.project_folder_result(tmp_path, "name1")

    assert not result.passed
    assert str(tmp_path / "name1") in result.detail
    assert "on the Mac run: sbx-start" in result.hint


def test_project_folder_fails_for_an_empty_name(tmp_path):
    result = checks_sandbox.project_folder_result(tmp_path, "")

    assert not result.passed
    assert "SBX_NAME is not set" in result.detail


# ------------------------------------------------------------------------------
# State folder checks
# ------------------------------------------------------------------------------

def make_state_folders(state1: Path, name_list: list[str]) -> None:
    for name in name_list:
        (state1 / name).mkdir(parents=True)


def test_state_folders_pass_when_base_and_extra_folders_exist(tmp_path):
    state1 = tmp_path / "state1"
    make_state_folders(state1, ["shell", "gh", "git", "cache/npm", "m2"])

    result = checks_sandbox.state_folders_result(state1, "cache/npm m2")

    assert result.passed


def test_state_folders_fail_naming_the_missing_folder(tmp_path):
    state1 = tmp_path / "state1"
    make_state_folders(state1, ["shell", "gh", "git", "cache/npm"])

    result = checks_sandbox.state_folders_result(state1, "cache/npm m2")

    assert not result.passed
    assert "m2" in result.detail
    assert "cache/npm" not in result.detail
    assert "on the Mac run: sbx-stop" in result.hint


def test_state_writable_passes_and_leaves_the_folder_empty(tmp_path):
    state1 = tmp_path / "state1"
    state1.mkdir()

    result = checks_sandbox.state_writable_result(state1)

    assert result.passed
    assert list(state1.iterdir()) == []


@pytest.mark.skipif(os.getuid() == 0, reason="root can write to a read-only folder")
def test_state_writable_fails_for_a_read_only_folder(tmp_path, restorable_mode):
    state1 = tmp_path / "state1"
    state1.mkdir()
    restorable_mode(state1, 0o555)

    result = checks_sandbox.state_writable_result(state1)

    assert not result.passed
    assert "on the Mac run: sbx-stop" in result.hint


def test_state_writable_fails_for_a_missing_folder(tmp_path):
    result = checks_sandbox.state_writable_result(tmp_path / "state1")

    assert not result.passed


# ------------------------------------------------------------------------------
# Root-owned state scan
# ------------------------------------------------------------------------------

def test_scan_owned_state_skips_tolerated_skipped_and_linked_trees(state_tree):
    path_list = checks_sandbox.scan_owned_state(state_tree, os.getuid(), {"cache/npm"}, {"gsd-core"})[0]

    assert path_list == ["cache", "sub1", "sub1/link1", "sub1/notes1"]


def test_scan_owned_state_finds_nothing_for_another_owner(state_tree):
    assert checks_sandbox.scan_owned_state(state_tree, os.getuid() + 1, set(), set())[0] == []


def test_scan_owned_state_reports_a_link_without_following_it(state_tree):
    path_list = checks_sandbox.scan_owned_state(state_tree, os.getuid(), set(), set())[0]

    assert "sub1/link1" in path_list

    for path in path_list:
        assert not path.startswith("sub1/link1/")


def make_fourteen_path_tree(state1: Path) -> None:
    for number in range(13):
        write_file(state1 / "sub1" / f"file{number:02d}")


def test_root_owned_state_fails_with_the_total_and_at_most_ten_paths(tmp_path):
    state1 = tmp_path / "state1"
    make_fourteen_path_tree(state1)

    result = checks_sandbox.root_owned_state_result(state1, os.getuid(), NAMED_ENVIRONMENT)

    assert not result.passed
    assert "14 paths" in result.detail
    assert result.detail.count("sub1") == 10
    assert result.hint == (
        "give the paths back to the sandbox user from a throwaway root container, "
        "since the sandbox cannot change owners: on the Mac run: "
        "docker run --rm --network none -u root --entrypoint chown "
        f"--volumes-from sbx-name1 sbx-base:local -R 1000:1000 {state1}"
    )


def test_root_owned_state_hint_says_name_when_sbx_name_is_unset(tmp_path):
    state1 = tmp_path / "state1"
    make_fourteen_path_tree(state1)

    result = checks_sandbox.root_owned_state_result(state1, os.getuid(), {})

    assert not result.passed
    assert "--volumes-from sbx-NAME sbx-base:local -R 1000:1000" in result.hint


def test_root_owned_state_prints_the_mac_owner_fix_under_its_fail_line(tmp_path):
    state1 = tmp_path / "state1"
    make_fourteen_path_tree(state1)

    def scan_state1():
        return checks_sandbox.root_owned_state_result(state1, os.getuid(), NAMED_ENVIRONMENT)

    check = selfcheck_core.Check("no-root-owned-state", scan_state1)
    line_list = sbx_selfcheck.outcome_lines(check.name, sbx_selfcheck.run_check(check))

    assert line_list[0].startswith("FAIL: no-root-owned-state: 14 paths under state/")
    assert line_list[1] == (
        "      fix: give the paths back to the sandbox user from a throwaway root container, "
        "since the sandbox cannot change owners: on the Mac run: "
        "docker run --rm --network none -u root --entrypoint chown "
        f"--volumes-from sbx-name1 sbx-base:local -R 1000:1000 {state1}"
    )


def test_scan_owned_state_counts_tolerated_paths_and_skips_cache_folders(tmp_path):
    state1 = tmp_path / "state1"
    write_file(state1 / "sub1" / "gsd-core" / "file1")
    write_file(state1 / "sub1" / "hooks" / "file2")
    write_file(state1 / "cache" / "npm" / "file3")
    write_file(state1 / "m2" / "file4")
    (state1 / "sub1" / "gsd-core" / "link1").symlink_to(tmp_path)

    result = checks_sandbox.scan_owned_state(state1, os.getuid(), {"cache/npm", "m2"}, {"gsd-core", "hooks", "scripts"})

    assert result == (["cache", "sub1"], 5)


@pytest.mark.skipif(os.getuid() == 0, reason="root can open a mode 000 folder")
def test_scan_owned_state_marks_a_reported_folder_it_cannot_open(tmp_path, restorable_mode):
    state1 = tmp_path / "state1"
    write_file(state1 / "sub1" / "private1" / "file1")
    restorable_mode(state1 / "sub1" / "private1", 0o000)

    result = checks_sandbox.scan_owned_state(state1, os.getuid(), set(), set())

    assert result == (["sub1", "sub1/private1 (unreadable)"], 0)


@pytest.mark.skipif(os.getuid() == 0, reason="root can open a mode 000 folder")
def test_scan_owned_state_reports_an_unreadable_folder_of_another_owner(tmp_path, restorable_mode):
    state1 = tmp_path / "state1"
    write_file(state1 / "sub1" / "private1" / "file1")
    restorable_mode(state1 / "sub1" / "private1", 0o000)

    result = checks_sandbox.scan_owned_state(state1, os.getuid() + 1, set(), set())

    assert result == (["sub1/private1 (unreadable)"], 0)


@pytest.mark.skipif(os.getuid() == 0, reason="root can open a mode 000 folder")
def test_scan_owned_state_tolerates_an_unreadable_folder_in_a_sync_folder(tmp_path, restorable_mode):
    state1 = tmp_path / "state1"
    write_file(state1 / "sub1" / "gsd-core" / "file1")
    restorable_mode(state1 / "sub1" / "gsd-core", 0o000)

    result = checks_sandbox.scan_owned_state(state1, os.getuid(), set(), {"gsd-core"})

    assert result == (["sub1"], 1)


def test_scan_owned_state_finds_nothing_in_a_missing_state_folder(tmp_path):
    assert checks_sandbox.scan_owned_state(tmp_path / "state1", os.getuid(), set(), set()) == ([], 0)


@pytest.mark.skipif(os.getuid() == 0, reason="root can open a mode 000 folder")
def test_root_owned_state_names_an_unreadable_folder_with_the_mac_fix(tmp_path, restorable_mode):
    state1 = tmp_path / "state1"
    write_file(state1 / "sub1" / "private1" / "file1")
    restorable_mode(state1 / "sub1" / "private1", 0o000)

    result = checks_sandbox.root_owned_state_result(state1, os.getuid())

    assert not result.passed
    assert "or unreadable" in result.detail
    assert "sub1/private1 (unreadable)" in result.detail
    assert "raised" not in result.detail
    assert result.hint.startswith("give the paths back to the sandbox user")
    assert str(state1) in result.hint


@pytest.mark.skipif(os.getuid() == 0, reason="root can open a mode 444 folder")
def test_scan_owned_state_marks_a_folder_it_can_list_but_not_search(tmp_path, restorable_mode):
    state1 = tmp_path / "state1"
    write_file(state1 / "sub1" / "private1" / "file1")
    write_file(state1 / "sub1" / "private1" / "file2")
    restorable_mode(state1 / "sub1" / "private1", 0o444)

    result = checks_sandbox.scan_owned_state(state1, os.getuid(), set(), set())

    assert result == (["sub1", "sub1/private1 (unreadable)"], 0)


@pytest.mark.skipif(os.getuid() == 0, reason="root can open a mode 444 folder")
def test_scan_owned_state_tolerates_a_folder_it_cannot_search_in_a_sync_folder(tmp_path, restorable_mode):
    state1 = tmp_path / "state1"
    write_file(state1 / "sub1" / "gsd-core" / "file1")
    restorable_mode(state1 / "sub1" / "gsd-core", 0o444)

    result = checks_sandbox.scan_owned_state(state1, os.getuid(), set(), {"gsd-core"})

    assert result == (["sub1"], 1)


@pytest.mark.skipif(os.getuid() == 0, reason="root can open a mode 444 folder")
def test_root_owned_state_prints_the_owner_fix_for_a_folder_it_cannot_search(tmp_path, restorable_mode):
    state1 = tmp_path / "state1"
    write_file(state1 / "sub1" / "private1" / "file1")
    write_file(state1 / "sub1" / "private1" / "file2")
    restorable_mode(state1 / "sub1" / "private1", 0o444)

    def scan_state1():
        return checks_sandbox.root_owned_state_result(state1, os.getuid(), NAMED_ENVIRONMENT)

    check = selfcheck_core.Check("no-root-owned-state", scan_state1)
    line_list = sbx_selfcheck.outcome_lines(check.name, sbx_selfcheck.run_check(check))

    assert len(line_list) == 2
    assert line_list[0] == (
        f"FAIL: no-root-owned-state: 2 paths under state/ are owned by uid {os.getuid()} "
        "or unreadable: sub1, sub1/private1 (unreadable)"
    )
    assert "raised" not in line_list[0]
    assert line_list[1].startswith(
        "      fix: give the paths back to the sandbox user from a throwaway root container"
    )
    assert line_list[1].endswith(f"--volumes-from sbx-name1 sbx-base:local -R 1000:1000 {state1}")


# A real folder cannot make an entry stat fail with an error other than permission, so this test passes a listing that does.
class FailingStatPath(type(Path())):
    def lstat(self):
        raise OSError(errno.EIO, "I/O error")


def test_scan_owned_state_lets_an_entry_error_other_than_permission_surface(tmp_path):
    state1 = tmp_path / "state1"
    entry1 = FailingStatPath(state1 / "file1")

    def read_entry1(folder_path):
        return [entry1]

    with pytest.raises(OSError) as raised:
        checks_sandbox.scan_owned_state(state1, os.getuid(), set(), set(), read_entry1)

    assert raised.value.errno == errno.EIO


def test_root_owned_state_names_the_tolerated_count_on_a_pass(tmp_path):
    state1 = tmp_path / "state1"
    state1.mkdir()

    result = checks_sandbox.root_owned_state_result(state1, os.getuid() + 1)

    assert result.passed
    assert "outside the GSD sync folders (0 tolerated)" in result.detail


def test_state_walk_never_opens_a_file(state_tree, restorable_mode):
    unreadable1 = state_tree / "sub1" / "notes1"
    restorable_mode(unreadable1, 0o000)

    path_list = checks_sandbox.scan_owned_state(state_tree, os.getuid(), set(), set())[0]

    assert "sub1/notes1" in path_list


# ------------------------------------------------------------------------------
# Home, owner and git checks
# ------------------------------------------------------------------------------

def git_environment(system_file: Path, global_file: Path) -> dict[str, str]:
    return {
        "PATH": os.environ["PATH"],
        "HOME": str(global_file.parent),
        "GIT_CONFIG_SYSTEM": str(system_file),
        "GIT_CONFIG_GLOBAL": str(global_file),
        "GIT_CONFIG_NOSYSTEM": "1",
    }


def test_home_layout_passes_when_bashrc_and_local_exist(tmp_path):
    home1 = tmp_path / "home1"
    write_file(home1 / ".bashrc")
    (home1 / ".local").mkdir()

    assert checks_sandbox.home_layout_result(home1).passed


def test_home_layout_fails_naming_the_missing_one(tmp_path):
    home1 = tmp_path / "home1"
    write_file(home1 / ".bashrc")

    result = checks_sandbox.home_layout_result(home1)

    assert not result.passed
    assert ".local" in result.detail
    assert ".bashrc" not in result.detail
    assert "on the Mac run: sbx-upgrade" in result.hint


def test_owned_by_passes_for_the_owner(tmp_path):
    write_file(tmp_path / "path1")
    write_file(tmp_path / "path2")

    result = checks_sandbox.owned_by_result([tmp_path / "path1", tmp_path / "path2"], CURRENT_USER)

    assert result.passed


def test_owned_by_fails_naming_each_path_and_its_real_owner(tmp_path):
    write_file(tmp_path / "path1")
    write_file(tmp_path / "path2")

    result = checks_sandbox.owned_by_result([tmp_path / "path1", tmp_path / "path2"], "root")

    assert not result.passed
    assert f"{tmp_path / 'path1'} is owned by {CURRENT_USER}" in result.detail
    assert f"{tmp_path / 'path2'} is owned by {CURRENT_USER}" in result.detail


def test_owned_by_fails_for_a_missing_path(tmp_path):
    result = checks_sandbox.owned_by_result([tmp_path / "path1"], CURRENT_USER)

    assert not result.passed
    assert "path1 is missing" in result.detail


def test_safe_directory_passes_when_the_system_file_trusts_every_folder(tmp_path):
    system1 = tmp_path / "system1"
    system1.write_text("[safe]\n\tdirectory = *\n")

    result = checks_sandbox.safe_directory_result(git_environment(system1, tmp_path / "global1"))

    assert result.passed


def test_safe_directory_fails_when_the_system_file_trusts_one_folder(tmp_path):
    system1 = tmp_path / "system1"
    system1.write_text("[safe]\n\tdirectory = /folder1\n")

    result = checks_sandbox.safe_directory_result(git_environment(system1, tmp_path / "global1"))

    assert not result.passed
    assert "on the Mac run: sbx-upgrade" in result.hint


def test_safe_directory_fails_when_the_system_file_is_empty(tmp_path):
    system1 = tmp_path / "system1"
    system1.write_text("")

    assert not checks_sandbox.safe_directory_result(git_environment(system1, tmp_path / "global1")).passed


def test_git_identity_fails_for_an_empty_config_and_then_passes_without_printing_values(tmp_path):
    global1 = tmp_path / "global1"
    global1.write_text("")
    environment1 = git_environment(tmp_path / "system1", global1)

    empty_result = checks_sandbox.git_identity_result(environment1)

    assert not empty_result.passed
    assert "user.name" in empty_result.detail
    assert "user.email" in empty_result.detail
    assert "sbx-gh-login" in empty_result.hint

    subprocess.run(["git", "config", "--file", str(global1), "user.name", "name1"], check=True, env=environment1)
    subprocess.run(["git", "config", "--file", str(global1), "user.email", "name1@example.invalid"], check=True, env=environment1)

    set_result = checks_sandbox.git_identity_result(environment1)

    assert set_result.passed
    assert "name1@example.invalid" not in set_result.detail + set_result.hint
    assert "name1" not in set_result.detail.replace("user.name", "")


def test_git_identity_names_only_the_empty_one(tmp_path):
    global1 = tmp_path / "global1"
    environment1 = git_environment(tmp_path / "system1", global1)
    subprocess.run(["git", "config", "--file", str(global1), "user.name", "name1"], check=True, env=environment1)

    result = checks_sandbox.git_identity_result(environment1)

    assert not result.passed
    assert "user.email" in result.detail
    assert "user.name" not in result.detail


# ------------------------------------------------------------------------------
# Architecture check
# ------------------------------------------------------------------------------

def test_architecture_passes_with_the_machine_and_its_elf_value():
    result = checks_sandbox.architecture_result()

    assert result.passed
    assert result.detail.startswith(f"{platform.machine()}, ELF machine 0x")
