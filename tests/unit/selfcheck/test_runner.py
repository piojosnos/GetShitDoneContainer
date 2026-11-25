# --------------------------------------------------------------------------------
# Tests of the sbx-selfcheck runner
# --------------------------------------------------------------------------------
# Line format, fix lines, order, load failures and exit codes.
# They run against real files in tmp_path.
# --------------------------------------------------------------------------------

import subprocess
import sys
from pathlib import Path

import pytest

import hints
import runner
from check_result import Check, CheckResult, failed, passed
from helpers import AGENT_FILE_TEMPLATE, run_lines, write_agent_file


# --------------------------------------------------------------------------------
# Constants and helpers
# --------------------------------------------------------------------------------

def passing_check(name: str) -> Check:
    def run_passing() -> CheckResult:
        return passed(f"detail_{name}")

    return Check(name, run_passing)


def failing_check(name: str, hint: str) -> Check:
    def run_failing() -> CheckResult:
        return failed(f"broken_{name}", hint)

    return Check(name, run_failing)


# --------------------------------------------------------------------------------
# Output lines and order
# --------------------------------------------------------------------------------

def test_passing_checks_print_one_pass_line_each_in_list_order(agents1):
    check_list = [passing_check("check1"), passing_check("check2"), passing_check("check3")]

    status, line_list = run_lines(check_list, agents1)

    assert status == 0
    assert line_list == [
        "PASS: check1: detail_check1",
        "PASS: check2: detail_check2",
        "PASS: check3: detail_check3",
        "PASS: agent1: detail_agent1",
        "sbx-selfcheck: 4 checks, 0 failed",
    ]


def test_failing_check_has_exactly_one_fix_line_before_the_next_check(agents1):
    check_list = [passing_check("check1"), failing_check("check2", "hint1"), passing_check("check3")]

    status, line_list = run_lines(check_list, agents1)

    assert status == 1
    assert line_list == [
        "PASS: check1: detail_check1",
        "FAIL: check2: broken_check2",
        "      fix: hint1",
        "PASS: check3: detail_check3",
        "PASS: agent1: detail_agent1",
        "sbx-selfcheck: 4 checks, 1 failed",
    ]


def test_raising_check_becomes_a_fail_line_with_the_rebuild_hint(agents1):
    def run_raising() -> CheckResult:
        raise RuntimeError("line1\nline2")

    status, line_list = run_lines([Check("check1", run_raising), passing_check("check2")], agents1)

    assert status == 1
    assert line_list[0] == "FAIL: check1: raised RuntimeError: line1 line2"
    assert line_list[1].startswith("      fix: ")
    assert line_list[1].endswith(hints.rebuild_hint())
    assert line_list[2] == "PASS: check2: detail_check2"
    assert line_list[3] == "PASS: agent1: detail_agent1"


@pytest.mark.parametrize(
    "returned_value, type_name",
    [
        pytest.param(None, "NoneType", id="none"),
        pytest.param(True, "bool", id="bool"),
        pytest.param(("check1", "detail1"), "tuple", id="tuple"),
    ],
)
def test_a_check_that_returns_no_result_becomes_a_fail_line_with_the_rebuild_hint(
    agents1, returned_value, type_name
):
    def run_returning():
        return returned_value

    status, line_list = run_lines([Check("check1", run_returning), passing_check("check2")], agents1)

    assert status == 1
    assert line_list == [
        f"FAIL: check1: returned {type_name} instead of a CheckResult",
        "      fix: this is a bug in sbx-selfcheck or a broken image; "
        + hints.rebuild_hint(),
        "PASS: check2: detail_check2",
        "PASS: agent1: detail_agent1",
        "sbx-selfcheck: 3 checks, 1 failed",
    ]


def test_newlines_in_detail_and_hint_print_as_spaces(agents1):
    def run_untidy() -> CheckResult:
        return CheckResult(False, "detail1\r\ndetail2\ndetail3", "hint1\nhint2")

    _, line_list = run_lines([Check("check1", run_untidy)], agents1)

    assert line_list[:2] == ["FAIL: check1: detail1  detail2 detail3", "      fix: hint1 hint2"]


def test_agent_files_run_after_the_shared_list_sorted_by_file_name(tmp_path, group1):
    write_agent_file(group1, "agent2")
    write_agent_file(group1, "agent1")
    (group1 / "notes.txt").write_text("not a checks file")

    status, line_list = run_lines([passing_check("check1")], tmp_path)

    assert status == 0
    assert line_list == [
        "PASS: check1: detail_check1",
        "PASS: agent1: detail_agent1",
        "PASS: agent2: detail_agent2",
        "sbx-selfcheck: 3 checks, 0 failed",
    ]


def test_agent_dirs_run_in_dir_name_order_and_a_loose_file_is_ignored(tmp_path):
    write_agent_file(tmp_path / "group2", "agent3")
    write_agent_file(tmp_path / "group1", "agent2")
    write_agent_file(tmp_path / "group1", "agent1")
    (tmp_path / "loose1.py").write_text("raise RuntimeError('not loaded')\n")

    status, line_list = run_lines([passing_check("check1")], tmp_path)

    assert status == 0
    assert line_list == [
        "PASS: check1: detail_check1",
        "PASS: agent1: detail_agent1",
        "PASS: agent2: detail_agent2",
        "PASS: agent3: detail_agent3",
        "sbx-selfcheck: 4 checks, 0 failed",
    ]


def test_the_order_is_the_same_on_every_run(tmp_path, group1):
    write_agent_file(group1, "agent2")
    write_agent_file(group1, "agent1")
    check_list = [passing_check("check2"), passing_check("check1")]

    status1, lines1 = run_lines(check_list, tmp_path)
    status2, lines2 = run_lines(check_list, tmp_path)

    assert status1 == status2 == 0
    assert lines1 == lines2
    assert lines1[0] == "PASS: check2: detail_check2"
    assert lines1[1] == "PASS: check1: detail_check1"


# --------------------------------------------------------------------------------
# Load failures
# --------------------------------------------------------------------------------

def expected_no_agent_checks_lines(checks_dir: Path) -> list[str]:
    return [
        "PASS: check1: detail_check1",
        f"FAIL: load-agent-checks: found no agent checks in {checks_dir}, so the image's own checks did not run",
        "      fix: " + hints.rebuild_hint(),
        "sbx-selfcheck: 2 checks, 1 failed",
    ]


def test_empty_and_missing_agent_dirs_fail_naming_the_dir(tmp_path, group1):
    empty_dir = tmp_path / "empty1"
    empty_dir.mkdir()
    missing_dir = tmp_path / "missing1"

    empty_status, empty_lines = run_lines([passing_check("check1")], empty_dir)
    missing_status, missing_lines = run_lines([passing_check("check1")], missing_dir)

    assert empty_status == 1
    assert empty_lines == expected_no_agent_checks_lines(empty_dir)
    assert missing_status == 1
    assert missing_lines == expected_no_agent_checks_lines(missing_dir)


def test_an_agent_file_with_an_empty_check_list_is_no_agent_checks(tmp_path, group1):
    (group1 / "agent1.py").write_text("CHECK_LIST = []\n")

    status, line_list = run_lines([passing_check("check1")], tmp_path)

    assert status == 1
    assert line_list == expected_no_agent_checks_lines(tmp_path)


def test_a_broken_agent_file_alone_is_one_load_failure(tmp_path, group1):
    (group1 / "agent1.py").write_text("def broken(:\n")

    status, line_list = run_lines([passing_check("check1")], tmp_path)

    fail_line_list = []

    for line in line_list:
        if line.startswith("FAIL: "):
            fail_line_list.append(line)

        assert "load-agent-checks" not in line

    assert status == 1
    assert len(fail_line_list) == 1
    assert fail_line_list[0].startswith("FAIL: load-group1-agent1: ")
    assert line_list[-1] == "sbx-selfcheck: 2 checks, 1 failed"


def test_an_empty_shared_list_prints_the_agent_lines_only(agents1):
    status, line_list = run_lines([], agents1)

    assert status == 0
    assert line_list == ["PASS: agent1: detail_agent1", "sbx-selfcheck: 1 checks, 0 failed"]


def test_an_agent_file_with_a_syntax_error_is_one_load_failure(tmp_path, group1):
    (group1 / "agent1.py").write_text("def broken(:\n")
    write_agent_file(group1, "agent2")

    status, line_list = run_lines([], tmp_path)

    assert status == 1
    assert line_list[0].startswith("FAIL: load-group1-agent1: ")
    assert "did not load: SyntaxError" in line_list[0]
    assert line_list[1].endswith(hints.rebuild_hint())
    assert line_list[2] == "PASS: agent2: detail_agent2"
    assert line_list[3] == "sbx-selfcheck: 2 checks, 1 failed"


def test_an_agent_file_without_a_check_list_is_one_load_failure(tmp_path, group1):
    (group1 / "agent2.py").write_text("VALUE1 = 1\n")
    write_agent_file(group1, "agent1")

    status, line_list = run_lines([], tmp_path)

    assert status == 1
    assert line_list[0] == "PASS: agent1: detail_agent1"
    assert line_list[1].startswith("FAIL: load-group1-agent2: ")
    assert line_list[1].endswith("agent2.py defines no CHECK_LIST")
    assert line_list[2].startswith("      fix: ")


@pytest.mark.parametrize(
    "check_list_text",
    [
        "CHECK_LIST = None\n",
        "CHECK_LIST = 5\n",
        'CHECK_LIST = "check1"\n',
        'CHECK_LIST = ["check1"]\n',
        AGENT_FILE_TEMPLATE.format(name="agent2") + 'CHECK_LIST.append("check2")\n',
    ],
    ids=["none", "number", "text", "list_of_text", "list_with_a_text_item"],
)
def test_an_agent_file_with_a_malformed_check_list_is_one_load_failure(tmp_path, group1, check_list_text):
    agent_file = group1 / "agent1.py"
    agent_file.write_text(check_list_text)

    status, line_list = run_lines([passing_check("check1")], tmp_path)

    assert status == 1
    assert line_list == [
        "PASS: check1: detail_check1",
        f"FAIL: load-group1-agent1: {agent_file} defines a CHECK_LIST that is not a list of checks",
        "      fix: " + hints.rebuild_hint(),
        "sbx-selfcheck: 2 checks, 1 failed",
    ]


# --------------------------------------------------------------------------------
# Main and the launcher
# --------------------------------------------------------------------------------

def test_main_with_an_argument_exits_two_with_one_usage_line_on_stderr(tmp_path, capsys):
    status = runner.main(["extra"], tmp_path, tmp_path)

    captured = capsys.readouterr()
    assert status == 2
    assert captured.out == ""
    assert captured.err == "Usage: sbx-selfcheck (no arguments)\n"


def test_main_without_arguments_runs_the_checks_on_stdout(shared1, agents1, capsys):
    status = runner.main([], shared1, agents1)

    captured = capsys.readouterr()
    assert status == 0
    assert captured.out == "PASS: check1: detail_check1\nPASS: agent1: detail_agent1\nsbx-selfcheck: 2 checks, 0 failed\n"
    assert captured.err == ""


def test_the_launcher_file_exits_two_for_an_argument(repo_dir):
    launcher_path = repo_dir / "base" / "selfcheck" / "sbx-selfcheck"

    completed = subprocess.run(
        [sys.executable, str(launcher_path), "extra"],
        capture_output=True,
        text=True,
        stdin=subprocess.DEVNULL,
        timeout=60,
    )

    assert completed.returncode == 2
    assert completed.stdout == ""
    assert completed.stderr == "Usage: sbx-selfcheck (no arguments)\n"


# --------------------------------------------------------------------------------
# Line format and base files
# --------------------------------------------------------------------------------

def test_every_line_is_pass_fail_fix_or_the_summary(tmp_path, group1):
    (group1 / "agent1.py").write_text("raise RuntimeError('detail1')\n")
    write_agent_file(group1, "agent2")
    check_list = [passing_check("check1"), failing_check("check2", "hint1")]

    status, line_list = run_lines(check_list, tmp_path)

    assert status == 1

    for line in line_list:
        assert line.startswith(("PASS: ", "FAIL: ", "      fix: ", "sbx-selfcheck: "))
        assert not line.startswith("SKIP")


def test_the_base_files_name_no_agent(repo_dir):
    base_dir = repo_dir / "base" / "selfcheck"
    file_list = list(base_dir.glob("*.py")) + list((base_dir / "checks").glob("*.py")) + [base_dir / "sbx-selfcheck"]

    for base_file in file_list:
        text = base_file.read_text().lower()

        assert "claude" not in text, base_file.name
        assert "cursor" not in text, base_file.name
