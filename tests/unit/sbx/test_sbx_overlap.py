# --------------------------------------------------------------------------------
# Tests of the host path text and the overlap rules
# --------------------------------------------------------------------------------
# Real directories and symlinks under tmp_path. paths_overlap is called directly,
# so it has to resolve both paths itself.
# --------------------------------------------------------------------------------

import pytest

from sbx.cli import SbxError
from sbx.overlap import check_host_path, locate_dir, paths_overlap

PATH_TEXT_REFUSAL_LIST = [
    ("", "the host path is empty"),
    ("rel/x", "'rel/x' is not an absolute path; ~ and relative paths are not expanded"),
    ("~/x", "'~/x' is not an absolute path; ~ and relative paths are not expanded"),
    ("/a\nb", "the host path has a line break"),
    ("/a//b", "'/a//b' has an empty, . or .. part"),
    ("/a/./b", "'/a/./b' has an empty, . or .. part"),
    ("/a/../b", "'/a/../b' has an empty, . or .. part"),
    ("/a/..", "'/a/..' has an empty, . or .. part"),
    ("/a/.//", "'/a/.//' has an empty, . or .. part"),
]


# --------------------------------------------------------------------------------
# check_host_path
# --------------------------------------------------------------------------------

@pytest.mark.parametrize(("raw_path", "text"), PATH_TEXT_REFUSAL_LIST)
def test_a_host_path_with_a_bad_text_is_refused_with_its_wording(raw_path, text):
    with pytest.raises(SbxError) as error:
        check_host_path(raw_path)

    assert str(error.value) == text


# --------------------------------------------------------------------------------

@pytest.mark.parametrize(
    ("raw_path", "expected_path"),
    [("/a/b///", "/a/b"), ("/", "/"), ("///", "/"), ("/a b/c", "/a b/c"), ("/caf\u00e9", "/caf\u00e9")],
)
def test_a_good_host_path_loses_only_its_trailing_slashes(raw_path, expected_path):
    assert check_host_path(raw_path) == expected_path


# --------------------------------------------------------------------------------
# locate_dir
# --------------------------------------------------------------------------------

def test_locate_dir_gives_the_deepest_existing_directory_and_the_missing_parts(tmp_path):
    existing_dir = tmp_path / "a"
    existing_dir.mkdir()

    base, tail_list = locate_dir(str(existing_dir / "b" / "c"))

    assert base == str(existing_dir.resolve())
    assert tail_list == ["b", "c"]


# --------------------------------------------------------------------------------

def test_locate_dir_of_an_existing_directory_has_no_tail(tmp_path):
    base, tail_list = locate_dir(str(tmp_path))

    assert base == str(tmp_path.resolve())
    assert tail_list == []


# --------------------------------------------------------------------------------

def test_locate_dir_follows_a_symlink_to_the_directory_behind_it(tmp_path):
    target_dir = tmp_path / "a"
    target_dir.mkdir()
    link = tmp_path / "link1"
    link.symlink_to(target_dir)

    base, tail_list = locate_dir(str(link / "new"))

    assert base == str(target_dir.resolve())
    assert tail_list == ["new"]


# --------------------------------------------------------------------------------

@pytest.mark.parametrize("path", ["rel/x", "", "/x\0y"])
def test_locate_dir_refuses_a_path_it_cannot_resolve(path):
    with pytest.raises(ValueError):
        locate_dir(path)


# --------------------------------------------------------------------------------
# paths_overlap
# --------------------------------------------------------------------------------

@pytest.fixture
def sandbox_a(tmp_path):
    sandbox_dir = tmp_path / "a"
    (sandbox_dir / "b").mkdir(parents=True)

    return sandbox_dir


# --------------------------------------------------------------------------------

def test_a_path_with_a_dotdot_part_that_lands_inside_a_directory_overlaps_it(tmp_path, sandbox_a):
    assert paths_overlap(f"{tmp_path}/c/../a/b/q", str(sandbox_a))
    assert paths_overlap(str(sandbox_a), f"{tmp_path}/c/../a/b/q")


# --------------------------------------------------------------------------------

def test_a_dotdot_part_through_a_real_directory_is_resolved(tmp_path, sandbox_a):
    (tmp_path / "c").mkdir()

    assert paths_overlap(f"{tmp_path}/c/../a/b", str(sandbox_a))


# --------------------------------------------------------------------------------

def test_a_path_through_a_symlink_to_a_directory_overlaps_that_directory(tmp_path, sandbox_a):
    (tmp_path / "link1").symlink_to(sandbox_a)

    assert paths_overlap(f"{tmp_path}/link1/new", str(sandbox_a))
    assert paths_overlap(f"{tmp_path}/link1", str(sandbox_a))
    assert paths_overlap(str(sandbox_a), f"{tmp_path}/link1/new")


# --------------------------------------------------------------------------------

def test_a_directory_that_holds_another_through_a_symlink_overlaps_it(tmp_path, sandbox_a):
    (tmp_path / "link1").symlink_to(tmp_path)

    assert paths_overlap(f"{tmp_path}/link1", str(sandbox_a))
    assert paths_overlap(str(sandbox_a), f"{tmp_path}/link1")


# --------------------------------------------------------------------------------

def test_the_same_directory_and_one_inside_the_other_overlap(tmp_path, sandbox_a):
    assert paths_overlap(str(sandbox_a), str(sandbox_a))
    assert paths_overlap(str(sandbox_a / "b"), str(sandbox_a))
    assert paths_overlap(str(sandbox_a), str(sandbox_a / "b"))
    assert paths_overlap(str(tmp_path), str(sandbox_a))


# --------------------------------------------------------------------------------

def test_a_new_path_below_an_existing_directory_overlaps_it(tmp_path, sandbox_a):
    assert paths_overlap(str(sandbox_a / "in"), str(sandbox_a))
    assert paths_overlap(str(sandbox_a), str(sandbox_a / "in"))
    assert paths_overlap(str(sandbox_a / "in" / "deeper"), str(sandbox_a))


# --------------------------------------------------------------------------------

def test_two_paths_that_only_share_a_text_prefix_do_not_overlap(tmp_path, sandbox_a):
    assert not paths_overlap(str(tmp_path / "a-other"), str(sandbox_a))
    assert not paths_overlap(str(sandbox_a), str(tmp_path / "a-other"))
    assert not paths_overlap(str(tmp_path / "a-other" / "in"), str(sandbox_a))


# --------------------------------------------------------------------------------

def test_two_different_new_paths_do_not_overlap(tmp_path):
    assert not paths_overlap(str(tmp_path / "new1"), str(tmp_path / "new2"))
    assert not paths_overlap(str(tmp_path / "new1" / "x"), str(tmp_path / "new1" / "y"))


# --------------------------------------------------------------------------------

def test_two_existing_siblings_do_not_overlap(tmp_path):
    (tmp_path / "one1").mkdir()
    (tmp_path / "two1").mkdir()

    assert not paths_overlap(str(tmp_path / "one1"), str(tmp_path / "two1"))


# --------------------------------------------------------------------------------

def test_a_missing_tail_that_differs_only_in_letter_case_overlaps(sandbox_a):
    assert paths_overlap(str(sandbox_a / "New"), str(sandbox_a / "new"))
    assert paths_overlap(str(sandbox_a / "New" / "x"), str(sandbox_a / "new"))


# --------------------------------------------------------------------------------

def test_a_path_that_cannot_be_resolved_counts_as_an_overlap(tmp_path):
    assert paths_overlap("/x\0y", str(tmp_path))
    assert paths_overlap(str(tmp_path), "/x\0y")


# --------------------------------------------------------------------------------

def test_a_relative_path_counts_as_an_overlap(tmp_path):
    assert paths_overlap("rel/x", str(tmp_path))


# --------------------------------------------------------------------------------

def test_a_path_through_a_regular_file_is_compared_below_its_directory(tmp_path):
    file = tmp_path / "file1"
    file.write_text("text")
    other_dir = tmp_path / "other1"
    other_dir.mkdir()

    assert paths_overlap(str(file / "x"), str(tmp_path))
    assert not paths_overlap(str(file / "x"), str(other_dir))
