# ------------------------------------------------------------------------------
# Tests of the roots of the base image
# ------------------------------------------------------------------------------

from pathlib import Path

import image_roots
from helpers import load_shared_check, write_file

wrappers_root_owned = load_shared_check("250_wrappers_root_owned")
image_paths_protected = load_shared_check("260_image_paths_protected")


# ------------------------------------------------------------------------------
# Image roots
# ------------------------------------------------------------------------------

def test_the_sbx_commands_are_the_files_with_the_prefix_and_nothing_else_in_the_folder(tmp_path):
    write_file(tmp_path / "bin1" / "sbx-b")
    write_file(tmp_path / "bin1" / "sbx-a")
    write_file(tmp_path / "bin1" / "uv")
    write_file(tmp_path / "bin1" / "other-sbx-c")

    assert image_roots.sbx_command_list(tmp_path / "bin1") == [tmp_path / "bin1" / "sbx-a", tmp_path / "bin1" / "sbx-b"]


def test_a_folder_without_sbx_commands_gives_no_roots_but_the_folders(tmp_path):
    assert image_roots.sbx_command_list(tmp_path / "missing1") == []
    assert image_roots.base_root_list(tmp_path / "missing1") == image_roots.BASE_FOLDER_LIST


def test_the_base_roots_are_the_library_folders_the_config_folder_and_the_sbx_commands(tmp_path):
    write_file(tmp_path / "bin1" / "sbx-a")

    assert image_roots.base_root_list(tmp_path / "bin1") == [
        Path("/usr/local/lib/sbx"),
        Path("/usr/local/lib/sbx-selfcheck"),
        Path("/etc/sbx"),
        tmp_path / "bin1" / "sbx-a",
    ]


def test_the_ownership_check_and_the_protected_paths_check_share_the_base_roots():
    assert wrappers_root_owned.base_root_list is image_roots.base_root_list
    assert image_paths_protected.base_root_list is image_roots.base_root_list
