# Tests of the sandbox checks and the helpers they stand on. They run the logic
# on real files, real permissions and the real git, inside tmp_path.

import os
from pathlib import Path

import pytest

import sbx_selfcheck
import shared_checks

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


def test_owned_by_uid_paths_skips_tolerated_skipped_and_linked_trees(state_tree):
    path_list = shared_checks.owned_by_uid_paths(state_tree, os.getuid(), {"cache/npm"}, {"gsd-core"})

    assert path_list == ["cache", "sub1", "sub1/link1", "sub1/notes1"]


def test_owned_by_uid_paths_finds_nothing_for_another_owner(state_tree):
    assert shared_checks.owned_by_uid_paths(state_tree, os.getuid() + 1, set(), set()) == []


def test_owned_by_uid_paths_reports_a_link_without_following_it(state_tree):
    path_list = shared_checks.owned_by_uid_paths(state_tree, os.getuid(), set(), set())

    assert "sub1/link1" in path_list
    assert not any(path.startswith("sub1/link1/") for path in path_list)


def test_root_owned_state_fails_with_the_total_and_at_most_ten_paths(tmp_path):
    state1 = tmp_path / "state1"

    for number in range(13):
        write_file(state1 / "sub1" / f"file{number:02d}")

    result = shared_checks.root_owned_state_result(state1, os.getuid())

    assert not result.passed
    assert "14 paths" in result.detail
    assert result.detail.count("sub1") == 10
    assert "chown -R sandbox:sandbox" in result.hint


def test_scan_owned_state_counts_tolerated_paths_and_skips_cache_folders(tmp_path):
    state1 = tmp_path / "state1"
    write_file(state1 / "sub1" / "gsd-core" / "file1")
    write_file(state1 / "sub1" / "hooks" / "file2")
    write_file(state1 / "cache" / "npm" / "file3")
    write_file(state1 / "m2" / "file4")
    (state1 / "sub1" / "gsd-core" / "link1").symlink_to(tmp_path)

    result = shared_checks.scan_owned_state(state1, os.getuid(), {"cache/npm", "m2"}, {"gsd-core", "hooks", "scripts"})

    assert result == (["cache", "sub1"], 5)


def test_root_owned_state_names_the_tolerated_count_on_a_pass(tmp_path):
    state1 = tmp_path / "state1"
    state1.mkdir()

    result = shared_checks.root_owned_state_result(state1, os.getuid() + 1)

    assert result.passed
    assert "outside the GSD sync folders (0 tolerated)" in result.detail


def test_state_walk_never_opens_a_file(state_tree, restorable_mode):
    unreadable1 = state_tree / "sub1" / "notes1"
    restorable_mode(unreadable1, 0o000)

    path_list = shared_checks.owned_by_uid_paths(state_tree, os.getuid(), set(), set())

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


def test_the_shared_list_holds_the_sandbox_shape_checks_first():
    name_list = [check.name for check in shared_checks.CHECK_LIST]

    assert name_list == [
        "workspace-mount",
        "project-folder",
        "state-folders",
        "state-writable",
        "no-root-owned-state",
        "user-sandbox",
    ]
