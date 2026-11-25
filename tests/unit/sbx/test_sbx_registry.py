# --------------------------------------------------------------------------------
# Tests of the registry: NAME.json read, write and list, and the config directory
# --------------------------------------------------------------------------------
# Real files under tmp_path. A value in an entry is only ever text.
# --------------------------------------------------------------------------------

import json
from pathlib import Path

import pytest

from sbx import registry as registry_module
from sbx.cli import SbxError
from sbx.registry import Entry, config_dir as resolve_config_dir, entry_file, list_entry_names, read_entry, registry_dir
from sbx_helpers import write_json_entry

ROUND_TRIP_PATH_LIST = ["/x/with space/dir", "/x/it's", '/x/say "hi"', "/x/caf\u00e9", "/x/../y", "/x/dir/"]
BROKEN_CONTENT_LIST = [
    ("", "the entry {file} is not a JSON object"),
    ("not json", "the entry {file} is not a JSON object"),
    ("[]", "the entry {file} is not a JSON object"),
    ('"text"', "the entry {file} is not a JSON object"),
    ("{}", "the entry {file} has no absolute path"),
    ('{"agent": "claude"}', "the entry {file} has no absolute path"),
    ('{"path": 5, "agent": "claude"}', "the entry {file} has no absolute path"),
    ('{"path": "x/a", "agent": "claude"}', "the entry {file} has no absolute path"),
    ('{"path": "", "agent": "claude"}', "the entry {file} has no absolute path"),
    ('{"path": "/x/a"}', "the entry {file} names agent ''; the known agents are: claude cursor"),
    ('{"path": "/x/a", "agent": 5}', "the entry {file} names agent ''; the known agents are: claude cursor"),
    ('{"path": "/x/a", "agent": "codex"}', "the entry {file} names agent 'codex'; the known agents are: claude cursor"),
]


# --------------------------------------------------------------------------------
# Write and read
# --------------------------------------------------------------------------------

@pytest.mark.parametrize("path", ROUND_TRIP_PATH_LIST)
def test_an_entry_reads_back_as_written_with_the_path_untouched(registry, path):
    registry_module.write_entry(registry, Entry("sbx1", path, "claude"))

    assert read_entry(registry, "sbx1") == Entry("sbx1", path, "claude")


# --------------------------------------------------------------------------------

def test_a_path_that_is_a_symlink_is_stored_as_the_link_text(registry, tmp_path):
    target_dir = tmp_path / "target1"
    target_dir.mkdir()
    link = tmp_path / "link1"
    link.symlink_to(target_dir)

    registry_module.write_entry(registry, Entry("sbx1", str(link), "cursor"))

    assert read_entry(registry, "sbx1").path == str(link)


# --------------------------------------------------------------------------------

def test_a_command_substitution_in_a_path_is_only_text(registry, tmp_path):
    marker = tmp_path / "pwned"
    path = f"/x/$(touch {marker})"

    registry_module.write_entry(registry, Entry("sbx1", path, "claude"))
    entry = read_entry(registry, "sbx1")

    assert entry.path == path
    assert not marker.exists()


# --------------------------------------------------------------------------------

def test_the_file_holds_json_with_a_path_and_an_agent_and_a_final_newline(registry):
    registry_module.write_entry(registry, Entry("sbx1", "/x/sbx1", "cursor"))
    text = entry_file(registry, "sbx1").read_text(encoding="utf-8")

    assert json.loads(text) == {"path": "/x/sbx1", "agent": "cursor"}
    assert text.endswith("\n")


# --------------------------------------------------------------------------------

def test_write_makes_the_registry_directory_when_it_is_missing(config_dir):
    registry = registry_dir(config_dir)

    registry_module.write_entry(registry, Entry("sbx1", "/x/sbx1", "claude"))

    assert read_entry(registry, "sbx1").agent == "claude"


# --------------------------------------------------------------------------------

def test_write_refuses_an_existing_entry_and_leaves_its_bytes(registry):
    file = write_json_entry(registry, "sbx1", "/x/old", "claude")
    before = file.read_bytes()

    with pytest.raises(SbxError) as excinfo:
        registry_module.write_entry(registry, Entry("sbx1", "/x/new", "cursor"))

    assert str(excinfo.value) == f"could not write {file}; nothing was registered"
    assert file.read_bytes() == before


# --------------------------------------------------------------------------------

def test_write_refuses_when_the_registry_directory_cannot_be_made(config_dir):
    blocked = registry_dir(config_dir)
    blocked.write_text("a file where the directory should be")

    with pytest.raises(SbxError) as excinfo:
        registry_module.write_entry(blocked, Entry("sbx1", "/x/sbx1", "claude"))

    assert str(excinfo.value) == f"could not write {blocked / 'sbx1.json'}; nothing was registered"


# --------------------------------------------------------------------------------

def test_a_missing_entry_is_not_registered(registry):
    with pytest.raises(SbxError) as excinfo:
        read_entry(registry, "sbx1")

    assert str(excinfo.value) == "sbx1 is not registered; run: sbx-add sbx1 HOST_PATH"


# --------------------------------------------------------------------------------

def test_extra_keys_in_an_entry_are_ignored(registry):
    file = entry_file(registry, "sbx1")
    file.write_text('{"path": "/x/sbx1", "agent": "claude", "note": "later"}')

    assert read_entry(registry, "sbx1") == Entry("sbx1", "/x/sbx1", "claude")


# --------------------------------------------------------------------------------

@pytest.mark.parametrize("content,message", BROKEN_CONTENT_LIST)
def test_a_broken_entry_is_refused_with_a_message_that_names_the_file(registry, content, message):
    file = entry_file(registry, "sbx1")
    file.write_text(content)

    with pytest.raises(SbxError) as excinfo:
        read_entry(registry, "sbx1")

    assert str(excinfo.value) == message.format(file=file)


# --------------------------------------------------------------------------------

def test_a_file_that_is_not_text_is_a_broken_entry(registry):
    file = entry_file(registry, "sbx1")
    file.write_bytes(b"\xff\xfe\x00")

    with pytest.raises(SbxError) as excinfo:
        read_entry(registry, "sbx1")

    assert str(excinfo.value) == f"the entry {file} is not a JSON object"


# --------------------------------------------------------------------------------
# Listing
# --------------------------------------------------------------------------------

def test_only_regular_json_files_are_listed_in_byte_order(registry):
    write_json_entry(registry, "b", "/x/b", "claude")
    write_json_entry(registry, "a-2", "/x/a-2", "claude")
    write_json_entry(registry, "a", "/x/a", "claude")
    (registry / "sbx1").write_text("SBX_DIR=/x/sbx1\nSBX_AGENT=claude\n")
    (registry / ".DS_Store").write_bytes(b"\x00")
    (registry / "x.json").mkdir()

    assert list_entry_names(registry) == ["a", "a-2", "b"]


# --------------------------------------------------------------------------------

def test_a_missing_registry_lists_nothing(config_dir):
    assert list_entry_names(registry_dir(config_dir)) == []


# --------------------------------------------------------------------------------
# The config directory
# --------------------------------------------------------------------------------

def test_the_config_directory_is_the_variable_when_set():
    assert resolve_config_dir({"SBX_CONFIG_DIR": "/c/one", "HOME": "/h/one"}) == Path("/c/one")


# --------------------------------------------------------------------------------

@pytest.mark.parametrize("environ", [{"HOME": "/h/one"}, {"SBX_CONFIG_DIR": "", "HOME": "/h/one"}])
def test_the_config_directory_falls_back_to_home(environ):
    assert resolve_config_dir(environ) == Path("/h/one/.config/sbx")


# --------------------------------------------------------------------------------

@pytest.mark.parametrize("environ", [{}, {"HOME": ""}, {"SBX_CONFIG_DIR": "", "HOME": ""}])
def test_no_variable_and_no_home_is_refused(environ):
    with pytest.raises(SbxError) as excinfo:
        resolve_config_dir(environ)

    assert str(excinfo.value) == "HOME and SBX_CONFIG_DIR are both empty; set SBX_CONFIG_DIR to an absolute path"


# --------------------------------------------------------------------------------

def test_a_relative_config_directory_is_refused():
    with pytest.raises(SbxError) as excinfo:
        resolve_config_dir({"SBX_CONFIG_DIR": "rel/dir", "HOME": "/h/one"})

    assert str(excinfo.value) == "SBX_CONFIG_DIR must be an absolute path, not 'rel/dir'"


# --------------------------------------------------------------------------------

def test_the_registry_directory_and_the_entry_file_follow_the_config_directory():
    assert registry_dir(Path("/c/one")) == Path("/c/one/sandboxes")
    assert entry_file(Path("/c/one/sandboxes"), "sbx1") == Path("/c/one/sandboxes/sbx1.json")
