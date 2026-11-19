# ------------------------------------------------------------------------------
# Tests of the no best-practices copy check
# ------------------------------------------------------------------------------

from helpers import load_shared_check

no_best_practices_copy = load_shared_check("270_no_best_practices_copy")


# ------------------------------------------------------------------------------
# No best-practices copy
# ------------------------------------------------------------------------------

def test_no_best_practices_copy_passes_when_the_path_is_absent_and_fails_when_present(tmp_path):
    copy1 = tmp_path / "copy1"

    assert no_best_practices_copy.no_best_practices_copy_result(copy1).passed

    copy1.mkdir()
    result = no_best_practices_copy.no_best_practices_copy_result(copy1)

    assert not result.passed
    assert str(copy1) in result.detail
    assert "on the host run: sbx-upgrade" in result.hint


def test_no_best_practices_copy_fails_for_a_dangling_link(tmp_path):
    copy1 = tmp_path / "copy1"
    copy1.symlink_to(tmp_path / "missing1")

    assert not no_best_practices_copy.no_best_practices_copy_result(copy1).passed
