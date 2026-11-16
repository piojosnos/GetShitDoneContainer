# ------------------------------------------------------------------------------
# Tests of the project folder check
# ------------------------------------------------------------------------------

from helpers import load_shared_check

project_folder = load_shared_check("020_project_folder")


# ------------------------------------------------------------------------------
# Project folder
# ------------------------------------------------------------------------------

def test_project_folder_passes_when_the_folder_exists(tmp_path):
    (tmp_path / "name1").mkdir()

    result = project_folder.project_folder_result(tmp_path, "name1")

    assert result.passed
    assert str(tmp_path / "name1") in result.detail


def test_project_folder_fails_naming_the_missing_path(tmp_path):
    result = project_folder.project_folder_result(tmp_path, "name1")

    assert not result.passed
    assert str(tmp_path / "name1") in result.detail
    assert "on the Mac run: sbx-start" in result.hint


def test_project_folder_fails_for_an_empty_name(tmp_path):
    result = project_folder.project_folder_result(tmp_path, "")

    assert not result.passed
    assert "SBX_NAME is not set" in result.detail
