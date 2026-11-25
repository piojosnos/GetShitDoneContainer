# --------------------------------------------------------------------------------
# Tests of the path helpers
# --------------------------------------------------------------------------------

import paths


# --------------------------------------------------------------------------------
# Path helpers
# --------------------------------------------------------------------------------

def test_is_under_holds_for_the_root_itself_and_its_children_only():
    assert paths.is_under("/home", "/home")
    assert paths.is_under("/home/sandbox/bin", "/home")
    assert not paths.is_under("/homework/bin", "/home")


# --------------------------------------------------------------------------------

def test_path_is_present_holds_for_a_dangling_link(tmp_path):
    (tmp_path / "link1").symlink_to(tmp_path / "missing1")

    assert paths.path_is_present(tmp_path / "link1")
    assert not paths.path_is_present(tmp_path / "missing1")


# --------------------------------------------------------------------------------

def test_link_text_returns_the_link_text_and_none_for_a_file(tmp_path):
    (tmp_path / "file1").write_text("text1")
    (tmp_path / "link1").symlink_to("file1")

    assert paths.link_text(tmp_path / "link1") == "file1"
    assert paths.link_text(tmp_path / "file1") is None


# --------------------------------------------------------------------------------

def test_state_dir_name_list_puts_the_base_dirs_first_and_keeps_each_name_once():
    assert paths.state_dir_name_list("cache/npm claude claude shell") == [
        "shell", "gh", "git", "cache/npm", "claude",
    ]
    assert paths.state_dir_name_list("") == ["shell", "gh", "git"]
