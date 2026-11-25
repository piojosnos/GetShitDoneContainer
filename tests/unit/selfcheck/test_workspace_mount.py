# --------------------------------------------------------------------------------
# Tests of the workspace mount check
# --------------------------------------------------------------------------------
# Real files and a mountinfo file inside tmp_path.
# --------------------------------------------------------------------------------

import os

import pytest

import hints
from helpers import load_shared_check, write_mountinfo

workspace_mount = load_shared_check("010_workspace_mount")


# --------------------------------------------------------------------------------
# Workspace mount
# --------------------------------------------------------------------------------

def test_workspace_mount_passes_when_listed_and_writable(tmp_path):
    workspace1 = tmp_path / "workspace1"
    workspace1.mkdir()
    mountinfo1 = tmp_path / "mountinfo1"
    write_mountinfo(mountinfo1, [str(workspace1)])

    result = workspace_mount.workspace_mount_result(workspace1, mountinfo1)

    assert result.passed
    assert str(workspace1) in result.detail


def test_workspace_mount_fails_with_the_start_hint_when_not_listed(tmp_path):
    workspace1 = tmp_path / "workspace1"
    workspace1.mkdir()
    mountinfo1 = tmp_path / "mountinfo1"
    write_mountinfo(mountinfo1, ["/mount1"])

    result = workspace_mount.workspace_mount_result(workspace1, mountinfo1)

    assert not result.passed
    assert "in a sandbox started with sbx-start" in result.hint
    assert result.hint == hints.start_hint()


@pytest.mark.skipif(os.getuid() == 0, reason="root can write to a read-only directory")
def test_workspace_mount_fails_when_the_dir_is_not_writable(tmp_path, restorable_mode):
    workspace1 = tmp_path / "workspace1"
    workspace1.mkdir()
    mountinfo1 = tmp_path / "mountinfo1"
    write_mountinfo(mountinfo1, [str(workspace1)])
    restorable_mode(workspace1, 0o555)

    result = workspace_mount.workspace_mount_result(workspace1, mountinfo1)

    assert not result.passed
    assert "not writable" in result.detail
    assert "on the host run:" in result.hint
