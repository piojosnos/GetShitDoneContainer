# ------------------------------------------------------------------------------
# Tests of sbx-list: usage, a Docker failure, the table rows, the notes
# ------------------------------------------------------------------------------
# main runs in-process with a Docker recorder and a registry of real files under
# tmp_path; no case needs Docker.
# ------------------------------------------------------------------------------

from sbx.docker import DockerResult
from sbx.list_sandboxes import main
from sbx_helpers import environ_for, write_json_entry

PS_PREFIX = ["ps"]
RUNNING_PREFIX = ["container", "inspect", "--format", "{{.State.Running}}"]
CONTAINER_IMAGE_PREFIX = ["container", "inspect", "--format", "{{.Image}}"]
IMAGE_ID_PREFIX = ["image", "inspect", "--format", "{{.Id}}"]
HEADER_LINE = "NAME".ljust(31) + " " + "STATUS".ljust(20) + " PATH"
OLDER_IMAGE_NOTE = (
    "older image: sbx-start NAME recreates it on the current image; "
    "that closes its open shells and Claude sessions"
)
NO_SANDBOXES_LINE = "sbx-list: no sandboxes registered; register one with: sbx-add NAME HOST_PATH"
LEFTOVER_LABEL = (
    "Containers with the sbx.name label but no registry entry "
    "(sbx-add NAME HOST_PATH registers one again):"
)


def expected_row(name, status, path):
    return name.ljust(31) + " " + status.ljust(20) + " " + str(path)


def run_list(config_dir, recorder, argument_list=None, extra_map=None):
    return main(argument_list or [], environ_for(config_dir, extra_map), recorder)


# ------------------------------------------------------------------------------
# Usage and failures
# ------------------------------------------------------------------------------

def test_an_argument_prints_the_usage_and_exits_2_before_docker(config_dir, registry, recorder, capsys):
    write_json_entry(registry, "sbx1", "/x/sbx1", "claude")

    exit_code = run_list(config_dir, recorder, ["extra"])
    captured = capsys.readouterr()

    assert exit_code == 2
    assert captured.err == "Usage: sbx-list\n"
    assert captured.out == ""
    assert recorder.call_list == []


def test_a_failed_docker_ps_exits_1_and_prints_no_table(config_dir, registry, recorder, capsys):
    write_json_entry(registry, "sbx1", "/x/sbx1", "claude")
    recorder.answer(PS_PREFIX, DockerResult(1, ""))

    exit_code = run_list(config_dir, recorder)
    captured = capsys.readouterr()

    assert exit_code == 1
    assert captured.err == "sbx-list: cannot read the containers from Docker; is Docker running?\n"
    assert captured.out == ""


def test_an_unknown_image_tag_is_refused_before_docker(config_dir, registry, recorder, capsys):
    exit_code = run_list(config_dir, recorder, extra_map={"SBX_IMAGE_TAG": "latest"})
    captured = capsys.readouterr()

    assert exit_code == 1
    assert captured.err == "sbx-list: SBX_IMAGE_TAG must be local or test, not 'latest'\n"
    assert recorder.call_list == []


# ------------------------------------------------------------------------------
# Rows
# ------------------------------------------------------------------------------

def test_an_empty_registry_prints_the_none_line(config_dir, registry, recorder, capsys):
    exit_code = run_list(config_dir, recorder)
    captured = capsys.readouterr()

    assert exit_code == 0
    assert captured.out == NO_SANDBOXES_LINE + "\n"


def test_a_missing_registry_prints_the_none_line(config_dir, recorder, capsys):
    exit_code = run_list(config_dir, recorder)
    captured = capsys.readouterr()

    assert exit_code == 0
    assert captured.out == NO_SANDBOXES_LINE + "\n"


def test_rows_are_in_byte_order_with_one_status_word_each(config_dir, registry, recorder, capsys):
    write_json_entry(registry, "sbx3", "/x/sbx3", "claude")
    write_json_entry(registry, "sbx2", "/x/sbx2", "cursor")
    write_json_entry(registry, "sbx1", "/x/sbx1", "claude")
    recorder.answer(PS_PREFIX, DockerResult(0, "sbx-sbx2 exited\nsbx-sbx1 running\n"))
    recorder.answer(RUNNING_PREFIX, DockerResult(0, "true\n"))
    recorder.answer(CONTAINER_IMAGE_PREFIX, DockerResult(0, "sha256:one\n"))
    recorder.answer(IMAGE_ID_PREFIX, DockerResult(0, "sha256:one\n"))

    exit_code = run_list(config_dir, recorder)
    captured = capsys.readouterr()

    assert exit_code == 0
    assert captured.out.splitlines() == [
        HEADER_LINE,
        expected_row("sbx1", "running", "/x/sbx1"),
        expected_row("sbx2", "stopped", "/x/sbx2"),
        expected_row("sbx3", "no container", "/x/sbx3"),
    ]


def test_a_longer_name_sorts_after_its_prefix(config_dir, registry, recorder, capsys):
    write_json_entry(registry, "sbx2", "/x/sbx2", "claude")
    write_json_entry(registry, "sbx10", "/x/sbx10", "claude")
    write_json_entry(registry, "sbx1", "/x/sbx1", "claude")

    run_list(config_dir, recorder)
    row_list = capsys.readouterr().out.splitlines()[1:]

    assert [row.split()[0] for row in row_list] == ["sbx1", "sbx10", "sbx2"]


def test_a_container_of_another_sandbox_is_not_this_sandbox(config_dir, registry, recorder, capsys):
    write_json_entry(registry, "sbx1", "/x/sbx1", "claude")
    recorder.answer(PS_PREFIX, DockerResult(0, "sbx-sbx1-two running\n"))

    run_list(config_dir, recorder)
    captured = capsys.readouterr()

    assert captured.out.splitlines()[1] == expected_row("sbx1", "no container", "/x/sbx1")


def test_broken_entries_are_rows_that_name_their_file(config_dir, registry, recorder, capsys):
    empty_file = registry / "sbx1.json"
    empty_file.write_text("")
    relative_file = write_json_entry(registry, "sbx2", "x/sbx2", "claude")
    bad_name_file = write_json_entry(registry, "Sbx3", "/x/sbx3", "claude")
    write_json_entry(registry, "sbx4", "/x/sbx4", "claude")

    exit_code = run_list(config_dir, recorder)
    captured = capsys.readouterr()

    assert exit_code == 0
    assert captured.out.splitlines() == [
        HEADER_LINE,
        expected_row("Sbx3", "broken entry", bad_name_file),
        expected_row("sbx1", "broken entry", empty_file),
        expected_row("sbx2", "broken entry", relative_file),
        expected_row("sbx4", "no container", "/x/sbx4"),
    ]


def test_an_older_file_without_the_suffix_is_not_listed_or_mentioned(config_dir, registry, recorder, capsys):
    (registry / "sbx1").write_text("SBX_DIR=/x/sbx1\nSBX_AGENT=claude\n")

    exit_code = run_list(config_dir, recorder)
    captured = capsys.readouterr()

    assert exit_code == 0
    assert captured.out == NO_SANDBOXES_LINE + "\n"
    assert captured.err == ""


# ------------------------------------------------------------------------------
# Older image and leftovers
# ------------------------------------------------------------------------------

def test_a_running_sandbox_on_an_older_image_is_marked_and_explained(config_dir, registry, recorder, capsys):
    write_json_entry(registry, "sbx1", "/x/sbx1", "claude")
    recorder.answer(PS_PREFIX, DockerResult(0, "sbx-sbx1 running\n"))
    recorder.answer(RUNNING_PREFIX, DockerResult(0, "true\n"))
    recorder.answer(CONTAINER_IMAGE_PREFIX, DockerResult(0, "sha256:old\n"))
    recorder.answer(IMAGE_ID_PREFIX, DockerResult(0, "sha256:new\n"))

    exit_code = run_list(config_dir, recorder)
    captured = capsys.readouterr()

    assert exit_code == 0
    assert captured.out.splitlines() == [
        HEADER_LINE,
        expected_row("sbx1", "running, older image", "/x/sbx1"),
        OLDER_IMAGE_NOTE,
    ]
    assert ["image", "inspect", "--format", "{{.Id}}", "sbx-claude:local"] in recorder.call_list


def test_the_older_image_check_uses_the_image_of_the_entry_agent_and_tag(config_dir, registry, recorder, capsys):
    write_json_entry(registry, "sbx1", "/x/sbx1", "cursor")
    recorder.answer(PS_PREFIX, DockerResult(0, "sbx-sbx1 running\n"))
    recorder.answer(RUNNING_PREFIX, DockerResult(0, "true\n"))

    run_list(config_dir, recorder, extra_map={"SBX_IMAGE_TAG": "test"})
    captured = capsys.readouterr()

    assert ["image", "inspect", "--format", "{{.Id}}", "sbx-cursor:test"] in recorder.call_list
    assert captured.err.startswith("sbx-list: using the test images because SBX_IMAGE_TAG=test;")


def test_a_labeled_container_without_an_entry_is_listed_as_a_leftover(config_dir, registry, recorder, capsys):
    write_json_entry(registry, "sbx1", "/x/sbx1", "claude")
    recorder.answer(PS_PREFIX, DockerResult(0, "sbx-sbx1 exited\nsbx-other running\nsbx-another exited\n"))

    exit_code = run_list(config_dir, recorder)
    captured = capsys.readouterr()

    assert exit_code == 0
    assert captured.out.splitlines() == [
        HEADER_LINE,
        expected_row("sbx1", "stopped", "/x/sbx1"),
        "",
        LEFTOVER_LABEL,
        "  " + "sbx-another".ljust(35) + " stopped",
        "  " + "sbx-other".ljust(35) + " running",
    ]


def test_leftovers_are_listed_after_the_none_line_too(config_dir, registry, recorder, capsys):
    recorder.answer(PS_PREFIX, DockerResult(0, "sbx-other running\n"))

    run_list(config_dir, recorder)
    captured = capsys.readouterr()

    assert captured.out.splitlines() == [
        NO_SANDBOXES_LINE,
        "",
        LEFTOVER_LABEL,
        "  " + "sbx-other".ljust(35) + " running",
    ]
