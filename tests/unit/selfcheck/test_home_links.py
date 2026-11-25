# --------------------------------------------------------------------------------
# Tests of the home links result
# --------------------------------------------------------------------------------
# Real files and links inside tmp_path.
# --------------------------------------------------------------------------------

import os

import hints
import home_links


# --------------------------------------------------------------------------------
# Home links
# --------------------------------------------------------------------------------

def test_home_links_result_passes_when_each_link_holds_its_target_text(tmp_path):
    target1 = tmp_path / "target1"
    target1.mkdir()
    link1 = tmp_path / "link1"
    link2 = tmp_path / "link2"
    os.symlink(str(target1), link1)
    os.symlink(str(target1), link2)

    result = home_links.home_links_result([(link1, target1), (link2, target1)])

    assert result.passed
    assert str(link1) in result.detail
    assert str(link2) in result.detail


# --------------------------------------------------------------------------------

def test_home_links_result_fails_for_a_dir_in_place_of_a_link_and_for_another_target(tmp_path):
    target1 = tmp_path / "target1"
    target2 = tmp_path / "target2"
    target1.mkdir()
    target2.mkdir()
    dir1 = tmp_path / "dir1"
    dir1.mkdir()
    link2 = tmp_path / "link2"
    os.symlink(str(target2), link2)

    dir_result = home_links.home_links_result([(dir1, target1)])
    target_result = home_links.home_links_result([(link2, target1)])

    assert not dir_result.passed
    assert str(dir1) in dir_result.detail
    assert not target_result.passed
    assert str(link2) in target_result.detail
    assert target_result.hint == hints.rebuild_hint()
