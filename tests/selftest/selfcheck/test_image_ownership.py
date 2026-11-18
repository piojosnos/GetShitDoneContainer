# ------------------------------------------------------------------------------
# Tests of the image ownership result
# ------------------------------------------------------------------------------
# The rule runs on real files and modes in tmp_path, with the test user standing
# in for root.
# ------------------------------------------------------------------------------

import os

import pytest

import image_ownership
import image_roots
from helpers import write_file
from image_ownership import ImageRules


# ------------------------------------------------------------------------------
# Constants and helpers
# ------------------------------------------------------------------------------

def rules_for(tmp_path) -> ImageRules:
    return ImageRules(
        owner_uid=os.getuid(),
        owner_gid=os.getgid(),
        command_dir=tmp_path / "bin1",
        launcher_file_list=[tmp_path / "root1" / "launcher1", tmp_path / "root1" / "launcher2"],
    )


def make_good_tree(tmp_path) -> None:
    write_file(tmp_path / "root1" / "steps1" / "step1")
    write_file(tmp_path / "root1" / "launcher1")
    write_file(tmp_path / "root1" / "launcher2")
    write_file(tmp_path / "root1" / "sub1" / "file1")
    write_file(tmp_path / "bin1" / "sbx-a")
    write_file(tmp_path / "bin1" / "uv")

    for executable in ["root1/launcher1", "root1/launcher2", "bin1/sbx-a"]:
        (tmp_path / executable).chmod(0o755)

    for path in [tmp_path / "root1" / "steps1" / "step1", tmp_path / "root1" / "sub1" / "file1", tmp_path / "bin1" / "uv"]:
        path.chmod(0o644)

    for folder in [tmp_path / "root1", tmp_path / "root1" / "steps1", tmp_path / "root1" / "sub1", tmp_path / "bin1"]:
        folder.chmod(0o755)


# ------------------------------------------------------------------------------
# Image ownership
# ------------------------------------------------------------------------------

def test_a_tree_with_the_right_owner_and_modes_passes(tmp_path):
    make_good_tree(tmp_path)

    result = image_ownership.image_ownership_result([tmp_path / "root1", tmp_path / "bin1" / "sbx-a"], rules_for(tmp_path))

    assert result.passed
    assert "2 roots" in result.detail


def test_a_file_the_test_user_made_fails_when_the_expected_owner_is_root(tmp_path):
    make_good_tree(tmp_path)
    rules = ImageRules(command_dir=tmp_path / "bin1")

    result = image_ownership.image_ownership_result([tmp_path / "root1" / "sub1" / "file1"], rules)

    assert not result.passed
    assert f"{tmp_path / 'root1' / 'sub1' / 'file1'} is owned by {os.getuid()}:{os.getgid()}, expected 0:0" in result.detail
    assert "on the host run: sbx-upgrade" in result.hint


@pytest.mark.parametrize("mode", [0o664, 0o646, 0o777])
def test_a_file_writable_by_group_or_others_fails_and_names_its_mode(tmp_path, mode):
    make_good_tree(tmp_path)
    (tmp_path / "root1" / "sub1" / "file1").chmod(mode)

    result = image_ownership.image_ownership_result([tmp_path / "root1"], rules_for(tmp_path))

    assert not result.passed
    assert f"{tmp_path / 'root1' / 'sub1' / 'file1'} is writable by group or others ({mode:o})" in result.detail


def test_a_folder_writable_by_others_fails(tmp_path):
    make_good_tree(tmp_path)
    (tmp_path / "root1" / "sub1").chmod(0o757)

    result = image_ownership.image_ownership_result([tmp_path / "root1"], rules_for(tmp_path))

    assert f"{tmp_path / 'root1' / 'sub1'} is writable by group or others (757)" in result.detail


@pytest.mark.parametrize(
    "relative_path",
    ["root1/launcher1", "root1/launcher2", "bin1/sbx-a", "root1/sub1"],
)
def test_a_launcher_an_sbx_command_and_a_folder_must_be_executable(tmp_path, relative_path):
    make_good_tree(tmp_path)
    (tmp_path / relative_path).chmod(0o644)

    result = image_ownership.image_ownership_result([tmp_path / "root1", tmp_path / "bin1" / "sbx-a"], rules_for(tmp_path))

    assert not result.passed
    assert f"{tmp_path / relative_path} is not executable (644)" in result.detail


def test_a_file_in_a_step_folder_needs_no_executable_bit(tmp_path):
    make_good_tree(tmp_path)

    result = image_ownership.image_ownership_result([tmp_path / "root1" / "steps1"], rules_for(tmp_path))

    assert result.passed


def test_a_file_outside_the_launcher_list_is_not_reported_as_a_launcher(tmp_path):
    make_good_tree(tmp_path)
    write_file(tmp_path / "root1" / "launcher3")
    (tmp_path / "root1" / "launcher3").chmod(0o644)

    result = image_ownership.image_ownership_result([tmp_path / "root1" / "launcher3"], rules_for(tmp_path))

    assert result.passed


def test_the_default_rules_name_both_launchers():
    assert ImageRules().launcher_file_list == image_roots.LAUNCHER_FILE_LIST


def test_an_ordinary_file_needs_no_executable_bit(tmp_path):
    make_good_tree(tmp_path)

    result = image_ownership.image_ownership_result(
        [tmp_path / "root1" / "sub1" / "file1", tmp_path / "bin1" / "uv"],
        rules_for(tmp_path),
    )

    assert result.passed


def test_every_sbx_command_must_be_executable_whatever_its_name(tmp_path):
    make_good_tree(tmp_path)
    write_file(tmp_path / "bin1" / "sbx-b.sh")
    (tmp_path / "bin1" / "sbx-b.sh").chmod(0o644)

    result = image_ownership.image_ownership_result([tmp_path / "bin1" / "sbx-b.sh"], rules_for(tmp_path))

    assert not result.passed
    assert f"{tmp_path / 'bin1' / 'sbx-b.sh'} is not executable (644)" in result.detail


def test_a_new_file_under_a_root_is_covered_without_any_list(tmp_path):
    make_good_tree(tmp_path)
    write_file(tmp_path / "root1" / "sub1" / "new1")
    (tmp_path / "root1" / "sub1" / "new1").chmod(0o666)

    result = image_ownership.image_ownership_result([tmp_path / "root1"], rules_for(tmp_path))

    assert f"{tmp_path / 'root1' / 'sub1' / 'new1'} is writable by group or others (666)" in result.detail


def test_a_link_is_checked_for_its_owner_only(tmp_path):
    make_good_tree(tmp_path)
    (tmp_path / "bin1" / "sbx-link").symlink_to(tmp_path / "root1" / "launcher1")

    result = image_ownership.image_ownership_result([tmp_path / "bin1" / "sbx-link"], rules_for(tmp_path))

    assert result.passed


def test_a_missing_root_fails(tmp_path):
    result = image_ownership.image_ownership_result([tmp_path / "root1"], rules_for(tmp_path))

    assert not result.passed
    assert f"{tmp_path / 'root1'} is missing" in result.detail


@pytest.mark.skipif(os.getuid() == 0, reason="root can open a mode 000 folder")
def test_a_folder_it_cannot_open_fails(tmp_path, restorable_mode):
    make_good_tree(tmp_path)
    restorable_mode(tmp_path / "root1" / "sub1", 0o000)

    result = image_ownership.image_ownership_result([tmp_path / "root1"], rules_for(tmp_path))

    assert f"{tmp_path / 'root1' / 'sub1'} cannot be opened" in result.detail


def test_the_detail_names_at_most_ten_problems_and_the_total(tmp_path):
    make_good_tree(tmp_path)

    for number in range(13):
        write_file(tmp_path / "root1" / "sub1" / f"file{number:02d}")
        (tmp_path / "root1" / "sub1" / f"file{number:02d}").chmod(0o666)

    result = image_ownership.image_ownership_result([tmp_path / "root1"], rules_for(tmp_path))

    assert "13 problems" in result.detail
    assert result.detail.count(" is writable by group or others") == 10
