# --------------------------------------------------------------------------------
# Tests of the scan for root-owned state paths
# --------------------------------------------------------------------------------
# The scan runs on real files, real permissions and links inside tmp_path.
# --------------------------------------------------------------------------------

import errno
import os
from pathlib import Path

import pytest

import root_owned_scan
from helpers import write_file


# --------------------------------------------------------------------------------
# Constants and helpers
# --------------------------------------------------------------------------------

@pytest.fixture
def state_tree(tmp_path):
    state1 = tmp_path / "state1"
    outside1 = tmp_path / "outside1"
    write_file(state1 / "sub1" / "notes1")
    write_file(state1 / "sub1" / "gsd-core" / "file1")
    write_file(state1 / "cache" / "npm" / "file3")
    write_file(outside1 / "file4")
    (state1 / "sub1" / "link1").symlink_to(outside1)

    return state1


# --------------------------------------------------------------------------------

class FailingStatPath(type(Path())):
    def lstat(self):
        raise OSError(errno.EIO, "I/O error")


# --------------------------------------------------------------------------------
# The skip set and the walk
# --------------------------------------------------------------------------------

def test_the_skip_set_holds_the_cache_and_maven_dirs():
    assert root_owned_scan.SKIPPED_STATE_DIR_SET == {"cache/npm", "cache/uv", "m2"}


# --------------------------------------------------------------------------------

def test_scan_owned_state_skips_the_skipped_dirs_and_reports_a_sync_dir_like_any_other(state_tree):
    path_list = root_owned_scan.scan_owned_state(state_tree, os.getuid(), {"cache/npm"})

    assert path_list == [
        "cache",
        "sub1",
        "sub1/gsd-core",
        "sub1/gsd-core/file1",
        "sub1/link1",
        "sub1/notes1",
    ]


# --------------------------------------------------------------------------------

def test_scan_owned_state_finds_nothing_for_another_owner(state_tree):
    assert root_owned_scan.scan_owned_state(state_tree, os.getuid() + 1, set()) == []


# --------------------------------------------------------------------------------

def test_scan_owned_state_reports_a_link_without_following_it(state_tree):
    path_list = root_owned_scan.scan_owned_state(state_tree, os.getuid(), set())

    assert "sub1/link1" in path_list

    for path in path_list:
        assert not path.startswith("sub1/link1/")


# --------------------------------------------------------------------------------

def test_scan_owned_state_finds_nothing_in_a_missing_state_dir(tmp_path):
    assert root_owned_scan.scan_owned_state(tmp_path / "state1", os.getuid(), set()) == []


# --------------------------------------------------------------------------------

def test_scan_owned_state_lets_an_entry_error_other_than_permission_surface(tmp_path):
    state1 = tmp_path / "state1"
    write_file(state1 / "file1")

    with pytest.raises(OSError) as raised:
        root_owned_scan.scan_owned_state(FailingStatPath(state1), os.getuid(), set())

    assert raised.value.errno == errno.EIO


# --------------------------------------------------------------------------------

def test_the_state_walk_never_opens_a_file(state_tree, restorable_mode):
    restorable_mode(state_tree / "sub1" / "notes1", 0o000)

    path_list = root_owned_scan.scan_owned_state(state_tree, os.getuid(), set())

    assert "sub1/notes1" in path_list


# --------------------------------------------------------------------------------
# Unreadable directories
# --------------------------------------------------------------------------------

@pytest.mark.skipif(os.getuid() == 0, reason="root can open a mode 000 directory")
def test_scan_owned_state_marks_a_reported_dir_it_cannot_open(tmp_path, restorable_mode):
    state1 = tmp_path / "state1"
    write_file(state1 / "sub1" / "private1" / "file1")
    restorable_mode(state1 / "sub1" / "private1", 0o000)

    assert root_owned_scan.scan_owned_state(state1, os.getuid(), set()) == ["sub1", "sub1/private1 (unreadable)"]


# --------------------------------------------------------------------------------

@pytest.mark.skipif(os.getuid() == 0, reason="root can open a mode 000 directory")
def test_scan_owned_state_reports_an_unreadable_dir_of_another_owner(tmp_path, restorable_mode):
    state1 = tmp_path / "state1"
    write_file(state1 / "sub1" / "private1" / "file1")
    restorable_mode(state1 / "sub1" / "private1", 0o000)

    assert root_owned_scan.scan_owned_state(state1, os.getuid() + 1, set()) == ["sub1/private1 (unreadable)"]


# --------------------------------------------------------------------------------

@pytest.mark.skipif(os.getuid() == 0, reason="root can open a mode 444 directory")
def test_scan_owned_state_marks_a_dir_it_can_list_but_not_search(tmp_path, restorable_mode):
    state1 = tmp_path / "state1"
    write_file(state1 / "sub1" / "private1" / "file1")
    write_file(state1 / "sub1" / "private1" / "file2")
    restorable_mode(state1 / "sub1" / "private1", 0o444)

    assert root_owned_scan.scan_owned_state(state1, os.getuid(), set()) == ["sub1", "sub1/private1 (unreadable)"]


# --------------------------------------------------------------------------------

@pytest.mark.skipif(os.getuid() == 0, reason="root can open a mode 000 directory")
def test_scan_owned_state_marks_an_unreadable_sync_dir_like_any_other(tmp_path, restorable_mode):
    state1 = tmp_path / "state1"
    write_file(state1 / "sub1" / "gsd-core" / "file1")
    restorable_mode(state1 / "sub1" / "gsd-core", 0o000)

    assert root_owned_scan.scan_owned_state(state1, os.getuid(), set()) == ["sub1", "sub1/gsd-core (unreadable)"]


# --------------------------------------------------------------------------------
# The host fix
# --------------------------------------------------------------------------------

def test_owner_fix_hint_names_the_container_and_the_state_dir(tmp_path):
    state1 = tmp_path / "state1"

    assert root_owned_scan.owner_fix_hint(state1, {"SBX_NAME": "name1"}) == (
        "give the paths back to the sandbox user from a throwaway root container, "
        "since the sandbox cannot change owners: on the host run: "
        "docker run --rm --network none -u root --entrypoint chown "
        f"--volumes-from sbx-name1 sbx-base:local -R 1000:1000 {state1}"
    )


# --------------------------------------------------------------------------------

def test_owner_fix_hint_says_name_when_sbx_name_is_unset(tmp_path):
    assert "--volumes-from sbx-NAME sbx-base:local -R 1000:1000" in root_owned_scan.owner_fix_hint(tmp_path, {})
