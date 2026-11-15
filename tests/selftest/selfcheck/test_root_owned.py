# ------------------------------------------------------------------------------
# Tests of the root-owned result
# ------------------------------------------------------------------------------

import os

import root_owned
from helpers import write_file


# ------------------------------------------------------------------------------
# Root-owned paths
# ------------------------------------------------------------------------------

def test_root_owned_passes_on_the_real_root_files():
    result = root_owned.root_owned_result([("/etc/passwd", 0o644), ("/etc", 0o755)])

    assert result.passed
    assert "2 paths" in result.detail


def test_root_owned_fails_naming_uid_gid_and_mode_of_a_file_made_by_the_test_user(tmp_path):
    write_file(tmp_path / "path1")
    (tmp_path / "path1").chmod(0o644)

    result = root_owned.root_owned_result([(str(tmp_path / "path1"), 0o644)])

    assert not result.passed
    assert f"{tmp_path / 'path1'} is {os.getuid()}:{os.getgid()} 644, expected root:root 644" in result.detail
    assert "on the Mac run: sbx-upgrade" in result.hint


def test_root_owned_fails_for_a_missing_path(tmp_path):
    result = root_owned.root_owned_result([(str(tmp_path / "path1"), 0o644)])

    assert not result.passed
    assert "path1 is missing" in result.detail
