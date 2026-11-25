# --------------------------------------------------------------------------------
# Tests of the project directory check
# --------------------------------------------------------------------------------

from helpers import load_shared_check

project_dir = load_shared_check("020_project_dir")


# --------------------------------------------------------------------------------
# Project directory
# --------------------------------------------------------------------------------

def test_project_dir_passes_when_the_dir_exists(tmp_path):
    (tmp_path / "name1").mkdir()

    result = project_dir.project_dir_result(tmp_path, "name1")

    assert result.passed
    assert str(tmp_path / "name1") in result.detail


def test_project_dir_fails_naming_the_missing_path(tmp_path):
    result = project_dir.project_dir_result(tmp_path, "name1")

    assert not result.passed
    assert str(tmp_path / "name1") in result.detail
    assert "on the host run: sbx-start" in result.hint


def test_project_dir_fails_for_an_empty_name(tmp_path):
    result = project_dir.project_dir_result(tmp_path, "")

    assert not result.passed
    assert "SBX_NAME is not set" in result.detail
