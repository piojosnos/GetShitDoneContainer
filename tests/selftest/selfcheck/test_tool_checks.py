# ------------------------------------------------------------------------------
# Tests of the shared tool and image checks
# ------------------------------------------------------------------------------
# Tool pins, the versions record and line, the shells and the bundle copy. Real
# bash; a stand-in executable where output must vary.
# ------------------------------------------------------------------------------

import os
import shutil

import pytest

import checks_tools
import selfcheck_core
import shared_checks
from helpers import environment_with, write_stand_in, write_versions
from helpers import environment_with, write_stand_in, write_versions


def test_no_bundle_copy_passes_when_the_path_is_absent_and_fails_when_present(tmp_path):
    copy1 = tmp_path / "copy1"

    assert checks_tools.no_bundle_copy_result(copy1).passed

    copy1.mkdir()
    result = checks_tools.no_bundle_copy_result(copy1)

    assert not result.passed
    assert str(copy1) in result.detail
    assert "on the Mac run: sbx-upgrade" in result.hint


def test_no_bundle_copy_fails_for_a_dangling_link(tmp_path):
    copy1 = tmp_path / "copy1"
    copy1.symlink_to(tmp_path / "missing1")

    assert not checks_tools.no_bundle_copy_result(copy1).passed


# ------------------------------------------------------------------------------
# Tool and tzdata checks
# ------------------------------------------------------------------------------

def test_tool_gh_without_its_pin_reports_the_missing_pin_and_runs_nothing(tmp_path):
    empty_versions = tmp_path / "empty1.env"
    empty_versions.write_text("")

    result = checks_tools.tool_gh_result(empty_versions)

    assert not result.passed
    assert result.detail == f"GH_VERSION is not in {selfcheck_core.VERSIONS_FILE}"


def test_pinned_tool_lines_report_their_missing_pin(tmp_path):
    empty_versions = tmp_path / "empty1.env"
    empty_versions.write_text("")

    for pin_name, function in [
        ("NODE_VERSION", checks_tools.tool_node_result),
        ("UV_IMAGE", checks_tools.tool_uv_result),
        ("TEMURIN_IMAGE", checks_tools.tool_java_result),
        ("MAVEN_VERSION", checks_tools.tool_maven_result),
        ("GSD_CORE_VERSION", checks_tools.tool_gsd_result),
    ]:
        result = function(empty_versions)

        assert not result.passed
        assert result.detail.startswith(f"{pin_name} is not in ")


@pytest.mark.skipif(shutil.which("node") is None, reason="node is not installed here")
def test_tool_node_fails_when_the_pin_differs_from_the_installed_version(tmp_path):
    versions2 = write_versions(tmp_path / "versions2.env")
    versions2.write_text(versions2.read_text().replace("NODE_VERSION=24.21.0", "NODE_VERSION=0.0.1"))

    result = checks_tools.tool_node_result(versions2)

    assert not result.passed
    assert "the pin is 'v0.0.1'" in result.detail


def test_tzdata_passes_when_the_utc_zone_file_exists(tmp_path):
    utc_file = tmp_path / "UTC"
    utc_file.write_text("zone1")

    assert checks_tools.tzdata_result(utc_file).passed
    assert not checks_tools.tzdata_result(tmp_path / "missing1").passed


def test_every_tool_line_has_a_check_of_its_own(check_name_list_of):
    name_list = check_name_list_of(shared_checks.CHECK_LIST)

    for tool in [
        "git", "bash", "gh", "node", "python", "uv", "java", "keytool", "maven", "gsd", "jq", "rg", "unzip", "zip", "ssh",
        "make", "gcc",
    ]:
        assert f"tool-{tool}" in name_list

    assert "tool-versions" not in name_list


def test_tool_bash_resolves_to_the_image_outside_the_home():
    result = checks_tools.check_tool_bash()
    expected_path = os.path.realpath(shutil.which("bash"))

    assert result.passed
    assert result.detail == expected_path
    assert not result.detail.startswith("/home/")


@pytest.mark.skipif(shutil.which("keytool") is None, reason="keytool is not installed here")
def test_tool_keytool_resolves_to_the_jdk_outside_the_home():
    result = checks_tools.check_tool_keytool()
    expected_path = os.path.realpath(shutil.which("keytool"))

    assert result.passed
    assert result.detail == expected_path
    assert not result.detail.startswith("/home/")


# ------------------------------------------------------------------------------
# History-free environment, versions record and line file
# ------------------------------------------------------------------------------

def test_history_free_environment_points_the_history_at_dev_null_and_leaves_the_input_alone():
    environment1 = {"PATH": "/usr/bin", "HISTFILE": "/home/sandbox/history1"}

    result_environment = checks_tools.history_free_environment(environment1)

    assert result_environment["HISTFILE"] == "/dev/null"
    assert result_environment["PATH"] == "/usr/bin"
    assert environment1["HISTFILE"] == "/home/sandbox/history1"


def test_history_free_environment_defaults_to_the_process_environment():
    history_before = os.environ.get("HISTFILE")

    result_environment = checks_tools.history_free_environment()

    assert result_environment["HISTFILE"] == "/dev/null"
    assert result_environment["PATH"] == os.environ["PATH"]
    assert os.environ.get("HISTFILE") == history_before


def test_versions_record_passes_when_every_shared_pin_has_a_value(versions1):
    result = checks_tools.versions_record_result(versions1)

    assert result.passed
    assert str(versions1) in result.detail


def test_versions_record_names_the_pins_that_are_missing_or_empty(tmp_path, versions1):
    versions2 = tmp_path / "versions2.env"
    versions2.write_text(versions1.read_text().replace("GH_VERSION=2.102.0", "GH_VERSION=").replace("NODE_VERSION=24.21.0\n", ""))

    result = checks_tools.versions_record_result(versions2)

    assert not result.passed
    assert "GH_VERSION" in result.detail
    assert "NODE_VERSION" in result.detail
    assert "MAVEN_VERSION" not in result.detail


def test_versions_record_fails_when_the_file_is_missing(tmp_path):
    result = checks_tools.versions_record_result(tmp_path / "missing1.env")

    assert not result.passed
    assert "missing1.env" in result.detail


def test_versions_record_does_not_run_what_the_file_holds(tmp_path, versions1):
    marker1 = tmp_path / "marker1"
    versions2 = tmp_path / "versions2.env"
    versions2.write_text(versions1.read_text() + f"GH_VERSION=$(touch {marker1})\n")

    checks_tools.versions_record_result(versions2)

    assert not marker1.exists()


def test_versions_line_file_passes_for_one_line_ending_with_the_base_text(versions1, line1):
    line1.write_text("claude 1 | " + selfcheck_core.expected_base_versions_text(versions1) + "\n")

    assert checks_tools.versions_line_file_result(line1, versions1).passed


def test_versions_line_file_also_passes_for_the_base_text_alone(versions1, line1):
    line1.write_text(selfcheck_core.expected_base_versions_text(versions1) + "\n")

    assert checks_tools.versions_line_file_result(line1, versions1).passed


def test_versions_line_file_fails_for_two_lines_a_wrong_field_or_no_file(tmp_path, versions1, line1):
    base_text = selfcheck_core.expected_base_versions_text(versions1)

    line1.write_text(base_text + "\n" + base_text + "\n")
    assert not checks_tools.versions_line_file_result(line1, versions1).passed

    line1.write_text(base_text.replace("mvn 3.9.11", "mvn 3.9.12") + "\n")
    assert not checks_tools.versions_line_file_result(line1, versions1).passed

    assert not checks_tools.versions_line_file_result(tmp_path / "missing1", versions1).passed


def test_versions_line_file_reports_a_missing_pin(tmp_path, line1):
    empty_versions = tmp_path / "empty1.env"
    empty_versions.write_text("")
    line1.write_text("anything\n")

    assert checks_tools.versions_line_file_result(line1, empty_versions).detail.startswith("GSD_CORE_VERSION is not in ")


# ------------------------------------------------------------------------------
# Interactive and quiet shells
# ------------------------------------------------------------------------------

def test_interactive_shell_passes_when_it_prints_the_file_once_and_only_on_stdout(tmp_path, bin1, line1):
    line1.write_text("line one of the file\n")
    write_stand_in(bin1, "bash", f'if [ "$1" = "-i" ]; then cat {line1}; echo "no job control" >&2; fi')

    result = checks_tools.interactive_versions_line_result(line1, environment_with(bin1))

    assert result.passed


def test_interactive_shell_fails_when_it_prints_the_line_twice(bin1, line1):
    line1.write_text("line one of the file\n")
    write_stand_in(bin1, "bash", f"cat {line1}; cat {line1}")

    result = checks_tools.interactive_versions_line_result(line1, environment_with(bin1))

    assert not result.passed
    assert "an interactive shell printed 'line one of the file" in result.detail
    assert "sbx-upgrade" in result.hint


def test_interactive_shell_fails_when_it_prints_nothing(bin1, line1):
    line1.write_text("line one of the file\n")
    write_stand_in(bin1, "bash", "true")

    assert not checks_tools.interactive_versions_line_result(line1, environment_with(bin1)).passed


def test_interactive_shell_fails_when_the_versions_file_is_missing(tmp_path, bin1):
    write_stand_in(bin1, "bash", "true")

    result = checks_tools.interactive_versions_line_result(tmp_path / "missing1", environment_with(bin1))

    assert not result.passed
    assert "missing1" in result.detail


def test_interactive_shell_runs_with_the_history_file_pointed_at_dev_null(tmp_path, bin1, line1):
    line1.write_text("line one of the file\n")
    seen1 = tmp_path / "seen1"
    write_stand_in(bin1, "bash", f'printf "%s" "$HISTFILE" > {seen1}')
    environment1 = environment_with(bin1)
    environment1["HISTFILE"] = str(tmp_path / "history1")

    checks_tools.interactive_versions_line_result(line1, environment1)

    assert seen1.read_text() == "/dev/null"


def test_interactive_shell_does_not_touch_the_history_file_of_a_real_bash(tmp_path, line1):
    line1.write_text("line one of the file\n")
    home1 = tmp_path / "home1"
    home1.mkdir()
    history1 = home1 / "history1"
    history1.write_text("command one\ncommand two\n")
    environment1 = {"PATH": os.environ["PATH"], "HOME": str(home1), "HISTFILE": str(history1)}

    checks_tools.interactive_versions_line_result(line1, environment1)

    assert history1.read_text() == "command one\ncommand two\n"
    remaining_name_list = []

    for path in home1.iterdir():
        remaining_name_list.append(path.name)

    assert sorted(remaining_name_list) == ["history1"]


def test_quiet_shells_pass_when_both_flags_print_nothing(bin1):
    write_stand_in(bin1, "bash", "true")

    assert checks_tools.quiet_shells_result(environment_with(bin1)).passed


def test_quiet_shells_name_the_flag_and_the_line_of_a_noisy_login_shell(bin1):
    write_stand_in(bin1, "bash", 'if [ "$1" = "-lc" ]; then echo "noise1"; fi')

    result = checks_tools.quiet_shells_result(environment_with(bin1))

    assert not result.passed
    assert "bash -lc true printed 'noise1'" in result.detail
    assert "bash -c" not in result.detail
    assert "sbx-upgrade" in result.hint


def test_quiet_shells_fail_for_output_on_stderr_too(bin1):
    write_stand_in(bin1, "bash", 'if [ "$1" = "-c" ]; then echo "noise2" >&2; fi')

    result = checks_tools.quiet_shells_result(environment_with(bin1))

    assert not result.passed
    assert "bash -c true printed 'noise2'" in result.detail
