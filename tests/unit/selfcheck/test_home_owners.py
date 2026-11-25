# --------------------------------------------------------------------------------
# Tests of the home owners check
# --------------------------------------------------------------------------------

import os
import pwd

from helpers import load_shared_check, write_file

home_owners = load_shared_check("070_home_owners")


# --------------------------------------------------------------------------------
# Constants and helpers
# --------------------------------------------------------------------------------

CURRENT_USER = pwd.getpwuid(os.getuid()).pw_name


# --------------------------------------------------------------------------------
# Home owners
# --------------------------------------------------------------------------------

def test_owned_by_passes_for_the_owner(tmp_path):
    write_file(tmp_path / "path1")
    write_file(tmp_path / "path2")

    result = home_owners.owned_by_result([tmp_path / "path1", tmp_path / "path2"], CURRENT_USER)

    assert result.passed


def test_owned_by_fails_naming_each_path_and_its_real_owner(tmp_path):
    write_file(tmp_path / "path1")
    write_file(tmp_path / "path2")

    result = home_owners.owned_by_result([tmp_path / "path1", tmp_path / "path2"], "root")

    assert not result.passed
    assert f"{tmp_path / 'path1'} is owned by {CURRENT_USER}" in result.detail
    assert f"{tmp_path / 'path2'} is owned by {CURRENT_USER}" in result.detail


def test_owned_by_fails_for_a_missing_path(tmp_path):
    result = home_owners.owned_by_result([tmp_path / "path1"], CURRENT_USER)

    assert not result.passed
    assert "path1 is missing" in result.detail
