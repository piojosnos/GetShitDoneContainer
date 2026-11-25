# --------------------------------------------------------------------------------
# Tests of the home layout check
# --------------------------------------------------------------------------------

from helpers import load_shared_check, write_file

home_layout = load_shared_check("060_home_layout")


# --------------------------------------------------------------------------------
# Home layout
# --------------------------------------------------------------------------------

def test_home_layout_passes_when_bashrc_and_local_exist(tmp_path):
    home1 = tmp_path / "home1"
    write_file(home1 / ".bashrc")
    (home1 / ".local").mkdir()

    assert home_layout.home_layout_result(home1).passed


def test_home_layout_fails_naming_the_missing_one(tmp_path):
    home1 = tmp_path / "home1"
    write_file(home1 / ".bashrc")

    result = home_layout.home_layout_result(home1)

    assert not result.passed
    assert ".local" in result.detail
    assert ".bashrc" not in result.detail
    assert "on the host run: sbx-upgrade" in result.hint
