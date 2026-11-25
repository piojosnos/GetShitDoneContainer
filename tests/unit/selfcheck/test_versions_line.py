# --------------------------------------------------------------------------------
# Tests of the versions line checks
# --------------------------------------------------------------------------------
# A stand-in bash and real files stand for the image's shell and line file.
# --------------------------------------------------------------------------------

import os

import versions_text
from helpers import environment_with, load_shared_check, write_stand_in

versions_line = load_shared_check("240_versions_line")


# --------------------------------------------------------------------------------
# Versions line
# --------------------------------------------------------------------------------

def test_versions_line_file_passes_for_one_line_ending_with_the_base_text(versions1, line1):
    line1.write_text("claude 1 | " + versions_text.expected_base_versions_text(versions1) + "\n")

    assert versions_line.versions_line_file_result(line1, versions1).passed


# --------------------------------------------------------------------------------

def test_versions_line_file_also_passes_for_the_base_text_alone(versions1, line1):
    line1.write_text(versions_text.expected_base_versions_text(versions1) + "\n")

    assert versions_line.versions_line_file_result(line1, versions1).passed


# --------------------------------------------------------------------------------

def test_versions_line_file_fails_for_two_lines_a_wrong_field_or_no_file(tmp_path, versions1, line1):
    base_text = versions_text.expected_base_versions_text(versions1)

    line1.write_text(base_text + "\n" + base_text + "\n")
    assert not versions_line.versions_line_file_result(line1, versions1).passed

    line1.write_text(base_text.replace("mvn 3.9.11", "mvn 3.9.12") + "\n")
    assert not versions_line.versions_line_file_result(line1, versions1).passed

    assert not versions_line.versions_line_file_result(tmp_path / "missing1", versions1).passed


# --------------------------------------------------------------------------------

def test_versions_line_file_reports_a_missing_pin(tmp_path, line1):
    empty_versions = tmp_path / "empty1.env"
    empty_versions.write_text("")
    line1.write_text("anything\n")

    assert versions_line.versions_line_file_result(line1, empty_versions).detail.startswith("GSD_CORE_VERSION is not in ")


# --------------------------------------------------------------------------------

def test_interactive_shell_passes_when_it_prints_the_file_once_and_only_on_stdout(tmp_path, bin1, line1):
    line1.write_text("line one of the file\n")
    write_stand_in(bin1, "bash", f'if [ "$1" = "-i" ]; then cat {line1}; echo "no job control" >&2; fi')

    result = versions_line.interactive_versions_line_result(line1, environment_with(bin1))

    assert result.passed


# --------------------------------------------------------------------------------

def test_interactive_shell_fails_when_it_prints_the_line_twice(bin1, line1):
    line1.write_text("line one of the file\n")
    write_stand_in(bin1, "bash", f"cat {line1}; cat {line1}")

    result = versions_line.interactive_versions_line_result(line1, environment_with(bin1))

    assert not result.passed
    assert "an interactive shell printed 'line one of the file" in result.detail
    assert "sbx-upgrade" in result.hint


# --------------------------------------------------------------------------------

def test_interactive_shell_fails_when_it_prints_nothing(bin1, line1):
    line1.write_text("line one of the file\n")
    write_stand_in(bin1, "bash", "true")

    assert not versions_line.interactive_versions_line_result(line1, environment_with(bin1)).passed


# --------------------------------------------------------------------------------

def test_interactive_shell_fails_when_the_versions_file_is_missing(tmp_path, bin1):
    write_stand_in(bin1, "bash", "true")

    result = versions_line.interactive_versions_line_result(tmp_path / "missing1", environment_with(bin1))

    assert not result.passed
    assert "missing1" in result.detail


# --------------------------------------------------------------------------------

def test_interactive_shell_runs_with_the_history_file_pointed_at_dev_null(tmp_path, bin1, line1):
    line1.write_text("line one of the file\n")
    seen1 = tmp_path / "seen1"
    write_stand_in(bin1, "bash", f'printf "%s" "$HISTFILE" > {seen1}')
    environment1 = environment_with(bin1)
    environment1["HISTFILE"] = str(tmp_path / "history1")

    versions_line.interactive_versions_line_result(line1, environment1)

    assert seen1.read_text() == "/dev/null"


# --------------------------------------------------------------------------------

def test_interactive_shell_does_not_touch_the_history_file_of_a_real_bash(tmp_path, line1):
    line1.write_text("line one of the file\n")
    home1 = tmp_path / "home1"
    home1.mkdir()
    history1 = home1 / "history1"
    history1.write_text("command one\ncommand two\n")
    environment1 = {"PATH": os.environ["PATH"], "HOME": str(home1), "HISTFILE": str(history1)}

    versions_line.interactive_versions_line_result(line1, environment1)

    assert history1.read_text() == "command one\ncommand two\n"
    remaining_name_list = []

    for path in home1.iterdir():
        remaining_name_list.append(path.name)

    assert sorted(remaining_name_list) == ["history1"]


# --------------------------------------------------------------------------------

def test_quiet_shells_pass_when_both_flags_print_nothing(bin1):
    write_stand_in(bin1, "bash", "true")

    assert versions_line.quiet_shells_result(environment_with(bin1)).passed


# --------------------------------------------------------------------------------

def test_quiet_shells_name_the_flag_and_the_line_of_a_noisy_login_shell(bin1):
    write_stand_in(bin1, "bash", 'if [ "$1" = "-lc" ]; then echo "noise1"; fi')

    result = versions_line.quiet_shells_result(environment_with(bin1))

    assert not result.passed
    assert "bash -lc true printed 'noise1'" in result.detail
    assert "bash -c" not in result.detail
    assert "sbx-upgrade" in result.hint


# --------------------------------------------------------------------------------

def test_quiet_shells_fail_for_output_on_stderr_too(bin1):
    write_stand_in(bin1, "bash", 'if [ "$1" = "-c" ]; then echo "noise2" >&2; fi')

    result = versions_line.quiet_shells_result(environment_with(bin1))

    assert not result.passed
    assert "bash -c true printed 'noise2'" in result.detail
