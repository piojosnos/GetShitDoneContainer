# ------------------------------------------------------------------------------
# Tests of sbx-migrate-registry: old KEY=value entries become NAME.json
# ------------------------------------------------------------------------------
# Real files under tmp_path. Every old file must stay byte for byte as it was.
# ------------------------------------------------------------------------------

import json

import pytest

from sbx.names import NAME_RULE_TEXT
from sbx_helpers import environ_for, write_json_entry

COUNT_TEXT = "the old files are left in place and can be deleted once each sandbox starts"


def run_migrate(config_dir, argument_list=None, extra_map=None):
    from sbx.migrate_registry import main

    return main(argument_list or [], environ_for(config_dir, extra_map))


def plant_old_entry(registry, name, text):
    registry.mkdir(parents=True, exist_ok=True)
    file = registry / name
    file.write_bytes(text.encode("utf-8"))

    return file


def count_line(converted, done, failed):
    return f"sbx-migrate-registry: {converted} converted, {done} already done, {failed} not converted; {COUNT_TEXT}"


def snapshot(registry):
    byte_map = {}

    for file in sorted(registry.iterdir()):
        byte_map[file.name] = file.read_bytes()

    return byte_map


# ------------------------------------------------------------------------------
# Converting
# ------------------------------------------------------------------------------

def test_one_old_file_per_agent_is_converted_and_reported(config_dir, registry, capsys):
    plant_old_entry(registry, "sbx1", "SBX_DIR=/x/one dir\nSBX_AGENT=claude\n")
    plant_old_entry(registry, "sbx2", "SBX_DIR=/x/two\nSBX_AGENT=cursor\n")

    exit_code = run_migrate(config_dir)
    captured = capsys.readouterr()

    assert exit_code == 0
    assert captured.out.splitlines() == [
        "sbx-migrate-registry: sbx1: wrote sbx1.json (path /x/one dir, agent claude)",
        "sbx-migrate-registry: sbx2: wrote sbx2.json (path /x/two, agent cursor)",
        count_line(2, 0, 0),
    ]
    assert json.loads((registry / "sbx1.json").read_text()) == {"path": "/x/one dir", "agent": "claude"}
    assert json.loads((registry / "sbx2.json").read_text()) == {"path": "/x/two", "agent": "cursor"}


def test_the_old_files_stay_byte_for_byte_as_they_were(config_dir, registry):
    plant_old_entry(registry, "sbx1", "SBX_DIR=/x/one\nSBX_AGENT=claude")
    plant_old_entry(registry, "sbx2", "SBX_AGENT=codex\nSBX_DIR=/x/two\n")
    plant_old_entry(registry, "Bad_Name", "SBX_DIR=/x/bad\nSBX_AGENT=claude\n")
    before_map = snapshot(registry)

    run_migrate(config_dir)

    after_map = snapshot(registry)

    for name, content in before_map.items():
        assert after_map[name] == content


def test_a_value_is_read_as_text_and_the_last_line_of_a_key_wins(config_dir, registry, tmp_path):
    marker = tmp_path / "pwned"
    plant_old_entry(registry, "sbx1", f"SBX_DIR=/x/first\nSBX_DIR=/x/$(touch {marker})\nSBX_AGENT=cursor\nSBX_AGENT=claude\n")

    exit_code = run_migrate(config_dir)

    assert exit_code == 0
    assert json.loads((registry / "sbx1.json").read_text()) == {"path": f"/x/$(touch {marker})", "agent": "claude"}
    assert not marker.exists()


def test_lines_in_any_order_and_a_last_line_without_a_newline_read_the_same(config_dir, registry):
    plant_old_entry(registry, "sbx1", "SBX_AGENT=claude\nSBX_DIR=/x/swapped")

    run_migrate(config_dir)

    assert json.loads((registry / "sbx1.json").read_text()) == {"path": "/x/swapped", "agent": "claude"}


# ------------------------------------------------------------------------------
# Files that cannot be converted
# ------------------------------------------------------------------------------

def test_a_file_that_cannot_be_converted_is_reported_and_the_exit_is_1(config_dir, registry, capsys):
    plant_old_entry(registry, "Bad_Name", "SBX_DIR=/x/bad\nSBX_AGENT=claude\n")
    plant_old_entry(registry, "sbx1", "SBX_DIR=rel/dir\nSBX_AGENT=claude\n")
    plant_old_entry(registry, "sbx2", "SBX_DIR=/x/two\nSBX_AGENT=codex\n")
    plant_old_entry(registry, "sbx3", "SBX_DIR=/x/three\n")
    plant_old_entry(registry, "sbx4", "SBX_AGENT=claude\n")

    exit_code = run_migrate(config_dir)
    line_list = capsys.readouterr().out.splitlines()

    assert exit_code == 1
    assert line_list[0].startswith("sbx-migrate-registry: Bad_Name: not converted: ")
    assert NAME_RULE_TEXT in line_list[0]
    assert line_list[1:] == [
        "sbx-migrate-registry: sbx1: not converted: no absolute SBX_DIR",
        "sbx-migrate-registry: sbx2: not converted: agent 'codex' is not one of: claude cursor",
        "sbx-migrate-registry: sbx3: not converted: agent '' is not one of: claude cursor",
        "sbx-migrate-registry: sbx4: not converted: no absolute SBX_DIR",
        count_line(0, 0, 5),
    ]
    assert sorted(file.name for file in registry.iterdir()) == ["Bad_Name", "sbx1", "sbx2", "sbx3", "sbx4"]


def test_a_reserved_name_is_not_converted(config_dir, registry, capsys):
    plant_old_entry(registry, "state", "SBX_DIR=/x/state\nSBX_AGENT=claude\n")

    exit_code = run_migrate(config_dir)

    assert exit_code == 1
    assert "sbx-migrate-registry: state: not converted: 'state' is taken" in capsys.readouterr().out
    assert not (registry / "state.json").exists()


def test_a_file_that_is_not_text_is_not_converted(config_dir, registry, capsys):
    file = plant_old_entry(registry, "sbx1", "")
    file.write_bytes(b"\xff\xfe\x00")

    exit_code = run_migrate(config_dir)

    assert exit_code == 1
    assert f"sbx-migrate-registry: sbx1: not converted: cannot read {file}" in capsys.readouterr().out


# ------------------------------------------------------------------------------
# Reruns and what is not an old entry
# ------------------------------------------------------------------------------

def test_an_existing_json_entry_is_left_as_it_is(config_dir, registry, capsys):
    plant_old_entry(registry, "sbx1", "SBX_DIR=/x/old\nSBX_AGENT=claude\n")
    json_file = write_json_entry(registry, "sbx1", "/x/kept", "cursor")
    before = json_file.read_bytes()

    exit_code = run_migrate(config_dir)

    assert exit_code == 0
    assert capsys.readouterr().out.splitlines() == [
        "sbx-migrate-registry: sbx1: sbx1.json exists; left as it is",
        count_line(0, 1, 0),
    ]
    assert json_file.read_bytes() == before


def test_a_second_run_converts_nothing_and_changes_no_file(config_dir, registry, capsys):
    plant_old_entry(registry, "sbx1", "SBX_DIR=/x/one\nSBX_AGENT=claude\n")
    plant_old_entry(registry, "sbx2", "SBX_DIR=/x/two\nSBX_AGENT=cursor\n")
    run_migrate(config_dir)
    capsys.readouterr()
    before_map = snapshot(registry)

    exit_code = run_migrate(config_dir)

    assert exit_code == 0
    assert capsys.readouterr().out.splitlines() == [
        "sbx-migrate-registry: sbx1: sbx1.json exists; left as it is",
        "sbx-migrate-registry: sbx2: sbx2.json exists; left as it is",
        count_line(0, 2, 0),
    ]
    assert snapshot(registry) == before_map


def test_a_mixed_registry_reports_each_count(config_dir, registry, capsys):
    plant_old_entry(registry, "sbx1", "SBX_DIR=/x/one\nSBX_AGENT=claude\n")
    plant_old_entry(registry, "sbx2", "SBX_DIR=/x/two\nSBX_AGENT=claude\n")
    write_json_entry(registry, "sbx2", "/x/two", "claude")
    plant_old_entry(registry, "sbx3", "SBX_DIR=/x/three\nSBX_AGENT=nope\n")

    exit_code = run_migrate(config_dir)

    assert exit_code == 1
    assert capsys.readouterr().out.splitlines()[-1] == count_line(1, 1, 1)


def test_json_files_hidden_files_and_directories_are_not_old_entries(config_dir, registry, capsys):
    write_json_entry(registry, "sbx1", "/x/one", "claude")
    (registry / ".DS_Store").write_bytes(b"\x00")
    (registry / "sbx2").mkdir()

    exit_code = run_migrate(config_dir)

    assert exit_code == 0
    assert capsys.readouterr().out == f"sbx-migrate-registry: no old registry entries in {registry}\n"


@pytest.mark.parametrize("make_registry", [True, False])
def test_an_empty_or_missing_registry_prints_the_none_line(config_dir, make_registry, capsys):
    registry = config_dir / "sandboxes"

    if make_registry:
        registry.mkdir()

    exit_code = run_migrate(config_dir)

    assert exit_code == 0
    assert capsys.readouterr().out == f"sbx-migrate-registry: no old registry entries in {registry}\n"


# ------------------------------------------------------------------------------
# Usage and the image tag
# ------------------------------------------------------------------------------

def test_an_argument_prints_the_usage_and_exits_2(config_dir, registry, capsys):
    plant_old_entry(registry, "sbx1", "SBX_DIR=/x/one\nSBX_AGENT=claude\n")

    exit_code = run_migrate(config_dir, ["extra"])
    captured = capsys.readouterr()

    assert exit_code == 2
    assert captured.err == "Usage: sbx-migrate-registry\n"
    assert not (registry / "sbx1.json").exists()


def test_an_unknown_image_tag_is_refused_before_anything_is_written(config_dir, registry, capsys):
    plant_old_entry(registry, "sbx1", "SBX_DIR=/x/one\nSBX_AGENT=claude\n")

    exit_code = run_migrate(config_dir, extra_map={"SBX_IMAGE_TAG": "latest"})

    assert exit_code == 1
    assert capsys.readouterr().err == "sbx-migrate-registry: SBX_IMAGE_TAG must be local or test, not 'latest'\n"
    assert not (registry / "sbx1.json").exists()
