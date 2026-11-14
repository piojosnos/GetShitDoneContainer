# Tests of the sandbox checks and the helpers they stand on. They run the logic
# on real files, real permissions and the real git, inside tmp_path.

import os
import subprocess
from pathlib import Path

import pytest

import sbx_selfcheck
import shared_checks

CURRENT_USER = shared_checks.user_name_of(os.getuid())
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
def restorable_mode():
    restore_list = []

    def lower_mode(path: Path, mode: int) -> None:
        restore_list.append((path, path.stat().st_mode))
        path.chmod(mode)

    yield lower_mode

    for path, mode in reversed(restore_list):
        path.chmod(mode)


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


def test_mount_point_set_reads_the_fifth_field_of_each_line():
    text = ROOT_MOUNT_LINE + "\n" + MOUNT_LINE_TEMPLATE.format(number=2, mount_point="/mount1") + "\n"

    assert sbx_selfcheck.mount_point_set(text) == {"/", "/mount1"}


def test_mount_point_set_ignores_blank_and_short_lines():
    assert sbx_selfcheck.mount_point_set("\n1 0 8:1\n" + ROOT_MOUNT_LINE + "\n") == {"/"}


def test_workspace_mount_passes_when_listed_and_writable(tmp_path):
    workspace1 = tmp_path / "workspace1"
    workspace1.mkdir()
    mountinfo1 = tmp_path / "mountinfo1"
    write_mountinfo(mountinfo1, [str(workspace1)])

    result = shared_checks.workspace_mount_result(workspace1, mountinfo1)

    assert result.passed
    assert str(workspace1) in result.detail


def test_workspace_mount_fails_with_the_start_hint_when_not_listed(tmp_path, monkeypatch):
    monkeypatch.setenv("SBX_NAME", "name1")
    workspace1 = tmp_path / "workspace1"
    workspace1.mkdir()
    mountinfo1 = tmp_path / "mountinfo1"
    write_mountinfo(mountinfo1, ["/mount1"])

    result = shared_checks.workspace_mount_result(workspace1, mountinfo1)

    assert not result.passed
    assert "in a sandbox started with sbx-start" in result.hint
    assert "on the Mac run: sbx-start name1" in result.hint


@pytest.mark.skipif(os.getuid() == 0, reason="root can write to a read-only folder")
def test_workspace_mount_fails_when_the_folder_is_not_writable(tmp_path, restorable_mode):
    workspace1 = tmp_path / "workspace1"
    workspace1.mkdir()
    mountinfo1 = tmp_path / "mountinfo1"
    write_mountinfo(mountinfo1, [str(workspace1)])
    restorable_mode(workspace1, 0o555)

    result = shared_checks.workspace_mount_result(workspace1, mountinfo1)

    assert not result.passed
    assert "not writable" in result.detail
    assert "on the Mac run:" in result.hint


def test_project_folder_passes_when_the_folder_exists(tmp_path):
    (tmp_path / "name1").mkdir()

    result = shared_checks.project_folder_result(tmp_path, "name1")

    assert result.passed
    assert str(tmp_path / "name1") in result.detail


def test_project_folder_fails_naming_the_missing_path(tmp_path):
    result = shared_checks.project_folder_result(tmp_path, "name1")

    assert not result.passed
    assert str(tmp_path / "name1") in result.detail
    assert "on the Mac run: sbx-start" in result.hint


def test_project_folder_fails_for_an_empty_name(tmp_path):
    result = shared_checks.project_folder_result(tmp_path, "")

    assert not result.passed
    assert "SBX_NAME is not set" in result.detail


def make_state_folders(state1: Path, name_list: list[str]) -> None:
    for name in name_list:
        (state1 / name).mkdir(parents=True)


def test_state_folders_pass_when_base_and_extra_folders_exist(tmp_path):
    state1 = tmp_path / "state1"
    make_state_folders(state1, ["shell", "gh", "git", "cache/npm", "m2"])

    result = shared_checks.state_folders_result(state1, "cache/npm m2")

    assert result.passed


def test_state_folders_fail_naming_the_missing_folder(tmp_path):
    state1 = tmp_path / "state1"
    make_state_folders(state1, ["shell", "gh", "git", "cache/npm"])

    result = shared_checks.state_folders_result(state1, "cache/npm m2")

    assert not result.passed
    assert "m2" in result.detail
    assert "cache/npm" not in result.detail
    assert "on the Mac run: sbx-stop" in result.hint


def test_state_writable_passes_and_leaves_the_folder_empty(tmp_path):
    state1 = tmp_path / "state1"
    state1.mkdir()

    result = shared_checks.state_writable_result(state1)

    assert result.passed
    assert list(state1.iterdir()) == []


@pytest.mark.skipif(os.getuid() == 0, reason="root can write to a read-only folder")
def test_state_writable_fails_for_a_read_only_folder(tmp_path, restorable_mode):
    state1 = tmp_path / "state1"
    state1.mkdir()
    restorable_mode(state1, 0o555)

    result = shared_checks.state_writable_result(state1)

    assert not result.passed
    assert "on the Mac run: sbx-stop" in result.hint


def test_state_writable_fails_for_a_missing_folder(tmp_path):
    result = shared_checks.state_writable_result(tmp_path / "state1")

    assert not result.passed


def test_scan_owned_state_skips_tolerated_skipped_and_linked_trees(state_tree):
    path_list = shared_checks.scan_owned_state(state_tree, os.getuid(), {"cache/npm"}, {"gsd-core"})[0]

    assert path_list == ["cache", "sub1", "sub1/link1", "sub1/notes1"]


def test_scan_owned_state_finds_nothing_for_another_owner(state_tree):
    assert shared_checks.scan_owned_state(state_tree, os.getuid() + 1, set(), set())[0] == []


def test_scan_owned_state_reports_a_link_without_following_it(state_tree):
    path_list = shared_checks.scan_owned_state(state_tree, os.getuid(), set(), set())[0]

    assert "sub1/link1" in path_list

    for path in path_list:
        assert not path.startswith("sub1/link1/")


def make_fourteen_path_tree(state1: Path) -> None:
    for number in range(13):
        write_file(state1 / "sub1" / f"file{number:02d}")


def test_root_owned_state_fails_with_the_total_and_at_most_ten_paths(tmp_path, monkeypatch):
    monkeypatch.setenv("SBX_NAME", "name1")
    state1 = tmp_path / "state1"
    make_fourteen_path_tree(state1)

    result = shared_checks.root_owned_state_result(state1, os.getuid())

    assert not result.passed
    assert "14 paths" in result.detail
    assert result.detail.count("sub1") == 10
    assert result.hint == (
        "give the paths back to the sandbox user from a throwaway root container, "
        "since the sandbox cannot change owners: on the Mac run: "
        "docker run --rm --network none -u root --entrypoint chown "
        f"--volumes-from sbx-name1 sbx-base:local -R 1000:1000 {state1}"
    )


def test_root_owned_state_hint_says_name_when_sbx_name_is_unset(tmp_path, monkeypatch):
    monkeypatch.delenv("SBX_NAME", raising=False)
    state1 = tmp_path / "state1"
    make_fourteen_path_tree(state1)

    result = shared_checks.root_owned_state_result(state1, os.getuid())

    assert not result.passed
    assert "--volumes-from sbx-NAME sbx-base:local -R 1000:1000" in result.hint


def test_root_owned_state_prints_the_mac_owner_fix_under_its_fail_line(tmp_path, monkeypatch):
    monkeypatch.setenv("SBX_NAME", "name1")
    state1 = tmp_path / "state1"
    make_fourteen_path_tree(state1)

    def scan_state1():
        return shared_checks.root_owned_state_result(state1, os.getuid())

    check = sbx_selfcheck.Check("no-root-owned-state", scan_state1)
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

    result = shared_checks.scan_owned_state(state1, os.getuid(), {"cache/npm", "m2"}, {"gsd-core", "hooks", "scripts"})

    assert result == (["cache", "sub1"], 5)


@pytest.mark.skipif(os.getuid() == 0, reason="root can open a mode 000 folder")
def test_scan_owned_state_marks_a_reported_folder_it_cannot_open(tmp_path, restorable_mode):
    state1 = tmp_path / "state1"
    write_file(state1 / "sub1" / "private1" / "file1")
    restorable_mode(state1 / "sub1" / "private1", 0o000)

    result = shared_checks.scan_owned_state(state1, os.getuid(), set(), set())

    assert result == (["sub1", "sub1/private1 (unreadable)"], 0)


@pytest.mark.skipif(os.getuid() == 0, reason="root can open a mode 000 folder")
def test_scan_owned_state_reports_an_unreadable_folder_of_another_owner(tmp_path, restorable_mode):
    state1 = tmp_path / "state1"
    write_file(state1 / "sub1" / "private1" / "file1")
    restorable_mode(state1 / "sub1" / "private1", 0o000)

    result = shared_checks.scan_owned_state(state1, os.getuid() + 1, set(), set())

    assert result == (["sub1/private1 (unreadable)"], 0)


@pytest.mark.skipif(os.getuid() == 0, reason="root can open a mode 000 folder")
def test_scan_owned_state_tolerates_an_unreadable_folder_in_a_sync_folder(tmp_path, restorable_mode):
    state1 = tmp_path / "state1"
    write_file(state1 / "sub1" / "gsd-core" / "file1")
    restorable_mode(state1 / "sub1" / "gsd-core", 0o000)

    result = shared_checks.scan_owned_state(state1, os.getuid(), set(), {"gsd-core"})

    assert result == (["sub1"], 1)


def test_scan_owned_state_finds_nothing_in_a_missing_state_folder(tmp_path):
    assert shared_checks.scan_owned_state(tmp_path / "state1", os.getuid(), set(), set()) == ([], 0)


@pytest.mark.skipif(os.getuid() == 0, reason="root can open a mode 000 folder")
def test_root_owned_state_names_an_unreadable_folder_with_the_mac_fix(tmp_path, restorable_mode):
    state1 = tmp_path / "state1"
    write_file(state1 / "sub1" / "private1" / "file1")
    restorable_mode(state1 / "sub1" / "private1", 0o000)

    result = shared_checks.root_owned_state_result(state1, os.getuid())

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

    result = shared_checks.scan_owned_state(state1, os.getuid(), set(), set())

    assert result == (["sub1", "sub1/private1 (unreadable)"], 0)


@pytest.mark.skipif(os.getuid() == 0, reason="root can open a mode 444 folder")
def test_scan_owned_state_tolerates_a_folder_it_cannot_search_in_a_sync_folder(tmp_path, restorable_mode):
    state1 = tmp_path / "state1"
    write_file(state1 / "sub1" / "gsd-core" / "file1")
    restorable_mode(state1 / "sub1" / "gsd-core", 0o444)

    result = shared_checks.scan_owned_state(state1, os.getuid(), set(), {"gsd-core"})

    assert result == (["sub1"], 1)


@pytest.mark.skipif(os.getuid() == 0, reason="root can open a mode 444 folder")
def test_root_owned_state_prints_the_owner_fix_for_a_folder_it_cannot_search(tmp_path, restorable_mode, monkeypatch):
    monkeypatch.setenv("SBX_NAME", "name1")
    state1 = tmp_path / "state1"
    write_file(state1 / "sub1" / "private1" / "file1")
    write_file(state1 / "sub1" / "private1" / "file2")
    restorable_mode(state1 / "sub1" / "private1", 0o444)

    def scan_state1():
        return shared_checks.root_owned_state_result(state1, os.getuid())

    check = sbx_selfcheck.Check("no-root-owned-state", scan_state1)
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


def test_root_owned_state_names_the_tolerated_count_on_a_pass(tmp_path):
    state1 = tmp_path / "state1"
    state1.mkdir()

    result = shared_checks.root_owned_state_result(state1, os.getuid() + 1)

    assert result.passed
    assert "outside the GSD sync folders (0 tolerated)" in result.detail


def test_state_walk_never_opens_a_file(state_tree, restorable_mode):
    unreadable1 = state_tree / "sub1" / "notes1"
    restorable_mode(unreadable1, 0o000)

    path_list = shared_checks.scan_owned_state(state_tree, os.getuid(), set(), set())[0]

    assert "sub1/notes1" in path_list


def test_parse_versions_text_skips_comments_and_blank_lines_and_splits_once():
    text = "# comment1\n\nNAME1=a=b\n  NAME2 = value2 \nbroken line\n"

    assert sbx_selfcheck.parse_versions_text(text) == {"NAME1": "a=b", "NAME2": "value2"}


def test_pin_value_reads_a_name_from_the_file(tmp_path):
    versions1 = tmp_path / "versions1"
    versions1.write_text("# comment1\n\nNAME1=a=b\nNAME2=c\n")

    assert sbx_selfcheck.pin_value("NAME1", versions1) == "a=b"


def test_pin_value_is_empty_for_a_missing_name_or_file(tmp_path):
    versions1 = tmp_path / "versions1"
    versions1.write_text("NAME1=a\n")

    assert sbx_selfcheck.pin_value("NAME2", versions1) == ""
    assert sbx_selfcheck.pin_value("NAME1", tmp_path / "missing1") == ""


def test_missing_pin_result_fails_with_the_mac_rebuild_command(monkeypatch):
    monkeypatch.setenv("SBX_NAME", "name1")

    result = sbx_selfcheck.missing_pin_result("NAME1")

    assert not result.passed
    assert "NAME1" in result.detail
    assert "on the Mac run: sbx-upgrade name1" in result.hint


def test_run_command_captures_text_output_and_closes_stdin():
    completed = sbx_selfcheck.run_command(["cat"])

    assert completed.returncode == 0
    assert completed.stdout == ""


def test_run_command_passes_the_given_environment():
    completed = sbx_selfcheck.run_command(["env"], {"NAME1": "value1"})

    assert completed.stdout.strip() == "NAME1=value1"


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

    assert shared_checks.home_layout_result(home1).passed


def test_home_layout_fails_naming_the_missing_one(tmp_path):
    home1 = tmp_path / "home1"
    write_file(home1 / ".bashrc")

    result = shared_checks.home_layout_result(home1)

    assert not result.passed
    assert ".local" in result.detail
    assert ".bashrc" not in result.detail
    assert "on the Mac run: sbx-upgrade" in result.hint


def test_owned_by_passes_for_the_owner(tmp_path):
    write_file(tmp_path / "path1")
    write_file(tmp_path / "path2")

    result = shared_checks.owned_by_result([tmp_path / "path1", tmp_path / "path2"], CURRENT_USER)

    assert result.passed


def test_owned_by_fails_naming_each_path_and_its_real_owner(tmp_path):
    write_file(tmp_path / "path1")
    write_file(tmp_path / "path2")

    result = shared_checks.owned_by_result([tmp_path / "path1", tmp_path / "path2"], "root")

    assert not result.passed
    assert f"{tmp_path / 'path1'} is owned by {CURRENT_USER}" in result.detail
    assert f"{tmp_path / 'path2'} is owned by {CURRENT_USER}" in result.detail


def test_owned_by_fails_for_a_missing_path(tmp_path):
    result = shared_checks.owned_by_result([tmp_path / "path1"], CURRENT_USER)

    assert not result.passed
    assert "path1 is missing" in result.detail


def test_safe_directory_passes_when_the_system_file_trusts_every_folder(tmp_path):
    system1 = tmp_path / "system1"
    system1.write_text("[safe]\n\tdirectory = *\n")

    result = shared_checks.safe_directory_result(git_environment(system1, tmp_path / "global1"))

    assert result.passed


def test_safe_directory_fails_when_the_system_file_trusts_one_folder(tmp_path):
    system1 = tmp_path / "system1"
    system1.write_text("[safe]\n\tdirectory = /folder1\n")

    result = shared_checks.safe_directory_result(git_environment(system1, tmp_path / "global1"))

    assert not result.passed
    assert "on the Mac run: sbx-upgrade" in result.hint


def test_safe_directory_fails_when_the_system_file_is_empty(tmp_path):
    system1 = tmp_path / "system1"
    system1.write_text("")

    assert not shared_checks.safe_directory_result(git_environment(system1, tmp_path / "global1")).passed


def test_git_identity_fails_for_an_empty_config_and_then_passes_without_printing_values(tmp_path):
    global1 = tmp_path / "global1"
    global1.write_text("")
    environment1 = git_environment(tmp_path / "system1", global1)

    empty_result = shared_checks.git_identity_result(environment1)

    assert not empty_result.passed
    assert "user.name" in empty_result.detail
    assert "user.email" in empty_result.detail
    assert "sbx-gh-login" in empty_result.hint

    subprocess.run(["git", "config", "--file", str(global1), "user.name", "name1"], check=True, env=environment1)
    subprocess.run(["git", "config", "--file", str(global1), "user.email", "name1@example.invalid"], check=True, env=environment1)

    set_result = shared_checks.git_identity_result(environment1)

    assert set_result.passed
    assert "name1@example.invalid" not in set_result.detail + set_result.hint
    assert "name1" not in set_result.detail.replace("user.name", "")


def test_git_identity_names_only_the_empty_one(tmp_path):
    global1 = tmp_path / "global1"
    environment1 = git_environment(tmp_path / "system1", global1)
    subprocess.run(["git", "config", "--file", str(global1), "user.name", "name1"], check=True, env=environment1)

    result = shared_checks.git_identity_result(environment1)

    assert not result.passed
    assert "user.email" in result.detail
    assert "user.name" not in result.detail


def test_bundle_env_passes_when_the_url_matches_the_pin_and_the_dir_is_the_clone(tmp_path):
    versions1 = tmp_path / "versions1"
    versions1.write_text("BUNDLE_REPO_URL=https://example.invalid/repo1.git\n")
    environment1 = {"BUNDLE_REPO_URL": "https://example.invalid/repo1.git", "SBX_BUNDLE_DIR": str(sbx_selfcheck.BUNDLE_DIR)}

    assert shared_checks.bundle_env_result(versions1, environment1).passed


def test_bundle_env_fails_naming_the_wrong_one(tmp_path):
    versions1 = tmp_path / "versions1"
    versions1.write_text("BUNDLE_REPO_URL=https://example.invalid/repo1.git\n")
    environment1 = {"BUNDLE_REPO_URL": "https://example.invalid/repo2.git", "SBX_BUNDLE_DIR": str(sbx_selfcheck.BUNDLE_DIR)}

    result = shared_checks.bundle_env_result(versions1, environment1)

    assert not result.passed
    assert "BUNDLE_REPO_URL" in result.detail
    assert "SBX_BUNDLE_DIR" not in result.detail


def test_bundle_env_fails_through_the_missing_pin_when_the_pin_is_absent(tmp_path):
    versions1 = tmp_path / "versions1"
    versions1.write_text("OTHER1=value1\n")

    result = shared_checks.bundle_env_result(versions1, {})

    assert not result.passed
    assert "BUNDLE_REPO_URL is not in" in result.detail


def test_root_owned_passes_on_the_real_root_files():
    result = sbx_selfcheck.root_owned_result([("/etc/passwd", 0o644), ("/etc", 0o755)])

    assert result.passed
    assert "2 paths" in result.detail


def test_root_owned_fails_naming_uid_gid_and_mode_of_a_file_made_by_the_test_user(tmp_path):
    write_file(tmp_path / "path1")
    (tmp_path / "path1").chmod(0o644)

    result = sbx_selfcheck.root_owned_result([(str(tmp_path / "path1"), 0o644)])

    assert not result.passed
    assert f"{tmp_path / 'path1'} is {os.getuid()}:{os.getgid()} 644, expected root:root 644" in result.detail
    assert "on the Mac run: sbx-upgrade" in result.hint


def test_root_owned_fails_for_a_missing_path(tmp_path):
    result = sbx_selfcheck.root_owned_result([(str(tmp_path / "path1"), 0o644)])

    assert not result.passed
    assert "path1 is missing" in result.detail


@pytest.mark.skipif(os.getuid() == 0, reason="root can write everywhere")
def test_protected_paths_fail_for_a_writable_file_and_pass_after_chmod(tmp_path, restorable_mode):
    folder1 = tmp_path / "folder1"
    write_file(folder1 / "sub1" / "file1")
    mountinfo1 = tmp_path / "mountinfo1"
    write_mountinfo(mountinfo1, [])

    writable_result = sbx_selfcheck.protected_paths_result([folder1], mountinfo1)

    assert not writable_result.passed
    assert str(folder1 / "sub1" / "file1") in writable_result.detail

    restorable_mode(folder1 / "sub1" / "file1", 0o444)
    restorable_mode(folder1 / "sub1", 0o555)
    restorable_mode(folder1, 0o555)

    assert sbx_selfcheck.protected_paths_result([folder1], mountinfo1).passed


@pytest.mark.skipif(os.getuid() == 0, reason="root can write everywhere")
def test_protected_paths_fail_for_a_mount_below_the_folder(tmp_path, restorable_mode):
    folder1 = tmp_path / "folder1"
    write_file(folder1 / "sub1" / "file1")
    restorable_mode(folder1 / "sub1" / "file1", 0o444)
    restorable_mode(folder1 / "sub1", 0o555)
    restorable_mode(folder1, 0o555)
    mountinfo1 = tmp_path / "mountinfo1"
    write_mountinfo(mountinfo1, [str(folder1 / "sub1")])

    result = sbx_selfcheck.protected_paths_result([folder1], mountinfo1)

    assert not result.passed
    assert f"{folder1 / 'sub1'} is a mount point" in result.detail


@pytest.mark.skipif(os.getuid() == 0, reason="root can write everywhere")
def test_protected_paths_ignore_a_mount_beside_the_folder(tmp_path, restorable_mode):
    folder1 = tmp_path / "folder1"
    write_file(folder1 / "file1")
    restorable_mode(folder1 / "file1", 0o444)
    restorable_mode(folder1, 0o555)
    mountinfo1 = tmp_path / "mountinfo1"
    write_mountinfo(mountinfo1, [str(tmp_path / "folder10")])

    assert sbx_selfcheck.protected_paths_result([folder1], mountinfo1).passed


def test_protected_paths_fail_for_a_missing_path(tmp_path):
    mountinfo1 = tmp_path / "mountinfo1"
    write_mountinfo(mountinfo1, [])

    result = sbx_selfcheck.protected_paths_result([tmp_path / "folder1"], mountinfo1)

    assert not result.passed
    assert "folder1 is missing" in result.detail


@pytest.mark.skipif(os.getuid() == 0, reason="root can write everywhere")
def test_protected_paths_name_at_most_ten_entries_and_the_total(tmp_path):
    folder1 = tmp_path / "folder1"

    for number in range(13):
        write_file(folder1 / f"file{number:02d}")

    mountinfo1 = tmp_path / "mountinfo1"
    write_mountinfo(mountinfo1, [])

    result = sbx_selfcheck.protected_paths_result([folder1], mountinfo1)

    assert not result.passed
    assert "14 problems" in result.detail
    assert result.detail.count(" is writable") == 10


def test_protected_paths_do_not_follow_a_link_while_walking(tmp_path):
    folder1 = tmp_path / "folder1"
    outside1 = tmp_path / "outside1"
    folder1.mkdir()
    write_file(outside1 / "file1")
    (folder1 / "link1").symlink_to(outside1)
    mountinfo1 = tmp_path / "mountinfo1"
    write_mountinfo(mountinfo1, [])

    result = sbx_selfcheck.protected_paths_result([folder1], mountinfo1)

    assert "link1/file1" not in result.detail


def test_no_bundle_copy_passes_when_the_path_is_absent_and_fails_when_present(tmp_path):
    copy1 = tmp_path / "copy1"

    assert shared_checks.no_bundle_copy_result(copy1).passed

    copy1.mkdir()
    result = shared_checks.no_bundle_copy_result(copy1)

    assert not result.passed
    assert str(copy1) in result.detail
    assert "on the Mac run: sbx-upgrade" in result.hint


def test_no_bundle_copy_fails_for_a_dangling_link(tmp_path):
    copy1 = tmp_path / "copy1"
    copy1.symlink_to(tmp_path / "missing1")

    assert not shared_checks.no_bundle_copy_result(copy1).passed


def test_the_shared_list_holds_the_checks_in_the_final_order(check_name_list_of):
    name_list = check_name_list_of(shared_checks.CHECK_LIST)

    assert name_list == [
        "workspace-mount",
        "project-folder",
        "state-folders",
        "state-writable",
        "no-root-owned-state",
        "user-sandbox",
        "home-layout",
        "home-owners",
        "architecture",
        "git-safe-directory",
        "git-identity",
        "env-state-paths",
        "env-bundle",
        "java-home",
        "tool-git",
        "tool-bash",
        "tool-gh",
        "tool-node",
        "tool-python",
        "tool-uv",
        "tool-java",
        "tool-keytool",
        "tool-maven",
        "tool-gsd",
        "tool-jq",
        "tool-rg",
        "tool-unzip",
        "tool-zip",
        "tool-ssh",
        "tool-make",
        "tool-gcc",
        "tzdata",
        "versions-record",
        "versions-line-file",
        "versions-line-interactive",
        "versions-line-quiet",
        "wrappers-root-owned",
        "image-paths-protected",
        "no-bundle-copy",
        "extra-ca-system-bundle",
        "extra-ca-java-cacerts",
    ]
