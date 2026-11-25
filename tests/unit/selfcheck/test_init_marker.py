# --------------------------------------------------------------------------------
# Tests of the init marker check
# --------------------------------------------------------------------------------
# The marker is a file that sbx-init leaves when it passes.
# --------------------------------------------------------------------------------

import hints
from helpers import load_shared_check

init_marker = load_shared_check("035_init_marker")


# --------------------------------------------------------------------------------
# Init marker
# --------------------------------------------------------------------------------

def test_init_marker_passes_when_the_marker_file_is_there(tmp_path):
    marker1 = tmp_path / "marker1"
    marker1.write_text("")

    result = init_marker.init_marker_result(marker1)

    assert result.passed
    assert str(marker1) in result.detail


# --------------------------------------------------------------------------------

def test_init_marker_fails_with_the_init_hint_when_the_marker_is_missing(tmp_path):
    marker1 = tmp_path / "marker1"

    result = init_marker.init_marker_result(marker1)

    assert not result.passed
    assert str(marker1) in result.detail
    assert result.hint == hints.init_hint()


# --------------------------------------------------------------------------------

def test_init_marker_fails_when_a_dir_sits_at_the_marker_path(tmp_path):
    marker1 = tmp_path / "marker1"
    marker1.mkdir()

    result = init_marker.init_marker_result(marker1)

    assert not result.passed
    assert result.hint == hints.init_hint()


# --------------------------------------------------------------------------------

def test_the_check_list_holds_init_marker_only():
    assert [check.name for check in init_marker.CHECK_LIST] == ["init-marker"]
