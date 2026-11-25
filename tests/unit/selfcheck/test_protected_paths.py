# --------------------------------------------------------------------------------
# Tests of the protected paths result
# --------------------------------------------------------------------------------

import os

import pytest

import protected_paths
from helpers import write_file, write_mountinfo


# --------------------------------------------------------------------------------
# Protected paths
# --------------------------------------------------------------------------------

@pytest.mark.skipif(os.getuid() == 0, reason="root can write everywhere")
def test_protected_paths_fail_for_a_writable_file_and_pass_after_chmod(tmp_path, restorable_mode):
    dir1 = tmp_path / "dir1"
    write_file(dir1 / "sub1" / "file1")
    mountinfo1 = tmp_path / "mountinfo1"
    write_mountinfo(mountinfo1, [])

    writable_result = protected_paths.protected_paths_result([dir1], mountinfo1)

    assert not writable_result.passed
    assert str(dir1 / "sub1" / "file1") in writable_result.detail

    restorable_mode(dir1 / "sub1" / "file1", 0o444)
    restorable_mode(dir1 / "sub1", 0o555)
    restorable_mode(dir1, 0o555)

    assert protected_paths.protected_paths_result([dir1], mountinfo1).passed


# --------------------------------------------------------------------------------

@pytest.mark.skipif(os.getuid() == 0, reason="root can write everywhere")
def test_protected_paths_fail_for_a_mount_below_the_dir(tmp_path, restorable_mode):
    dir1 = tmp_path / "dir1"
    write_file(dir1 / "sub1" / "file1")
    restorable_mode(dir1 / "sub1" / "file1", 0o444)
    restorable_mode(dir1 / "sub1", 0o555)
    restorable_mode(dir1, 0o555)
    mountinfo1 = tmp_path / "mountinfo1"
    write_mountinfo(mountinfo1, [str(dir1 / "sub1")])

    result = protected_paths.protected_paths_result([dir1], mountinfo1)

    assert not result.passed
    assert f"{dir1 / 'sub1'} is a mount point" in result.detail


# --------------------------------------------------------------------------------

@pytest.mark.skipif(os.getuid() == 0, reason="root can write everywhere")
def test_protected_paths_ignore_a_mount_beside_the_dir(tmp_path, restorable_mode):
    dir1 = tmp_path / "dir1"
    write_file(dir1 / "file1")
    restorable_mode(dir1 / "file1", 0o444)
    restorable_mode(dir1, 0o555)
    mountinfo1 = tmp_path / "mountinfo1"
    write_mountinfo(mountinfo1, [str(tmp_path / "dir10")])

    assert protected_paths.protected_paths_result([dir1], mountinfo1).passed


# --------------------------------------------------------------------------------

def test_protected_paths_fail_for_a_missing_path(tmp_path):
    mountinfo1 = tmp_path / "mountinfo1"
    write_mountinfo(mountinfo1, [])

    result = protected_paths.protected_paths_result([tmp_path / "dir1"], mountinfo1)

    assert not result.passed
    assert "dir1 is missing" in result.detail


# --------------------------------------------------------------------------------

@pytest.mark.skipif(os.getuid() == 0, reason="root can write everywhere")
def test_protected_paths_name_at_most_ten_entries_and_the_total(tmp_path):
    dir1 = tmp_path / "dir1"

    for number in range(13):
        write_file(dir1 / f"file{number:02d}")

    mountinfo1 = tmp_path / "mountinfo1"
    write_mountinfo(mountinfo1, [])

    result = protected_paths.protected_paths_result([dir1], mountinfo1)

    assert not result.passed
    assert "14 problems" in result.detail
    assert result.detail.count(" is writable") == 10


# --------------------------------------------------------------------------------

def test_protected_paths_do_not_follow_a_link_while_walking(tmp_path):
    dir1 = tmp_path / "dir1"
    outside1 = tmp_path / "outside1"
    dir1.mkdir()
    write_file(outside1 / "file1")
    (dir1 / "link1").symlink_to(outside1)
    mountinfo1 = tmp_path / "mountinfo1"
    write_mountinfo(mountinfo1, [])

    result = protected_paths.protected_paths_result([dir1], mountinfo1)

    assert "link1/file1" not in result.detail
