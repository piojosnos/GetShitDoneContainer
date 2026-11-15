# ------------------------------------------------------------------------------
# Tests of the sbx-selfcheck runner
# ------------------------------------------------------------------------------
# Line format, fix lines, order, load failures, exit codes and hint builders.
# They run against real files in tmp_path.
# ------------------------------------------------------------------------------

import io
import subprocess
import sys
from pathlib import Path

import pytest

import sbx_selfcheck
import selfcheck_core
from selfcheck_core import Check, CheckResult, failed, passed


# ------------------------------------------------------------------------------
# Constants and helpers
# ------------------------------------------------------------------------------

AGENT_FILE_TEMPLATE = """from selfcheck_core import Check, passed


def check_{name}():
    return passed("detail_{name}")


CHECK_LIST = [Check("{name}", check_{name})]
"""


def passing_check(name: str) -> Check:
    def run_passing() -> CheckResult:
        return passed(f"detail_{name}")

    return Check(name, run_passing)


def failing_check(name: str, hint: str) -> Check:
    def run_failing() -> CheckResult:
        return failed(f"broken_{name}", hint)

    return Check(name, run_failing)


def run_lines(shared_check_list: list[Check], checks_dir: Path) -> tuple[int, list[str]]:
    output = io.StringIO()
    status = sbx_selfcheck.run_selfcheck(shared_check_list, checks_dir, output)

    return status, output.getvalue().splitlines()


def write_agent_file(checks_dir: Path, name: str) -> None:
    (checks_dir / f"{name}.py").write_text(AGENT_FILE_TEMPLATE.format(name=name))


@pytest.fixture
def agents1(tmp_path) -> Path:
    agents_dir = tmp_path / "agents1"
    agents_dir.mkdir()
    write_agent_file(agents_dir, "agent1")

    return agents_dir


# ------------------------------------------------------------------------------
# Output lines and order
# ------------------------------------------------------------------------------

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


def test_failed_refuses_an_empty_or_blank_hint():
    with pytest.raises(ValueError):
        failed("detail1", "")

    with pytest.raises(ValueError):
        failed("detail1", "   ")


def test_raising_check_becomes_a_fail_line_with_the_rebuild_hint(agents1, monkeypatch):
    monkeypatch.setenv("SBX_NAME", "sbx1")

    def run_raising() -> CheckResult:
        raise RuntimeError("line1\nline2")

    status, line_list = run_lines([Check("check1", run_raising), passing_check("check2")], agents1)

    assert status == 1
    assert line_list[0] == "FAIL: check1: raised RuntimeError: line1 line2"
    assert line_list[1].startswith("      fix: ")
    assert "on the Mac run: sbx-upgrade sbx1" in line_list[1]
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
    agents1, monkeypatch, returned_value, type_name
):
    monkeypatch.setenv("SBX_NAME", "sbx1")

    def run_returning():
        return returned_value

    status, line_list = run_lines([Check("check1", run_returning), passing_check("check2")], agents1)

    assert status == 1
    assert line_list == [
        f"FAIL: check1: returned {type_name} instead of a CheckResult",
        "      fix: this is a bug in the self-check or a broken image; "
        "rebuild the image and recreate the sandbox: on the Mac run: sbx-upgrade sbx1",
        "PASS: check2: detail_check2",
        "PASS: agent1: detail_agent1",
        "sbx-selfcheck: 3 checks, 1 failed",
    ]


def test_newlines_in_detail_and_hint_print_as_spaces():
    result = CheckResult(False, "detail1\r\ndetail2\ndetail3", "hint1\nhint2")

    line_list = sbx_selfcheck.outcome_lines("check1", result)

    assert line_list == ["FAIL: check1: detail1  detail2 detail3", "      fix: hint1 hint2"]


def test_agent_files_run_after_the_shared_list_sorted_by_file_name(tmp_path):
    write_agent_file(tmp_path, "agent2")
    write_agent_file(tmp_path, "agent1")
    (tmp_path / "notes.txt").write_text("not a checks file")

    status, line_list = run_lines([passing_check("check1")], tmp_path)

    assert status == 0
    assert line_list == [
        "PASS: check1: detail_check1",
        "PASS: agent1: detail_agent1",
        "PASS: agent2: detail_agent2",
        "sbx-selfcheck: 3 checks, 0 failed",
    ]


def test_the_order_is_the_same_on_every_run(tmp_path):
    write_agent_file(tmp_path, "agent2")
    write_agent_file(tmp_path, "agent1")
    check_list = [passing_check("check2"), passing_check("check1")]

    status1, lines1 = run_lines(check_list, tmp_path)
    status2, lines2 = run_lines(check_list, tmp_path)

    assert status1 == status2 == 0
    assert lines1 == lines2
    assert lines1[0] == "PASS: check2: detail_check2"
    assert lines1[1] == "PASS: check1: detail_check1"


# ------------------------------------------------------------------------------
# Load failures
# ------------------------------------------------------------------------------

def expected_no_agent_checks_lines(checks_dir: Path) -> list[str]:
    return [
        "PASS: check1: detail_check1",
        f"FAIL: load-agent-checks: found no agent checks in {checks_dir}, so the image's own checks did not run",
        "      fix: rebuild the image and recreate the sandbox: on the Mac run: sbx-upgrade sbx1",
        "sbx-selfcheck: 2 checks, 1 failed",
    ]


def test_empty_and_missing_agent_folders_fail_naming_the_folder(tmp_path, monkeypatch):
    monkeypatch.setenv("SBX_NAME", "sbx1")
    empty_dir = tmp_path / "empty1"
    empty_dir.mkdir()
    missing_dir = tmp_path / "missing1"

    empty_status, empty_lines = run_lines([passing_check("check1")], empty_dir)
    missing_status, missing_lines = run_lines([passing_check("check1")], missing_dir)

    assert empty_status == 1
    assert empty_lines == expected_no_agent_checks_lines(empty_dir)
    assert missing_status == 1
    assert missing_lines == expected_no_agent_checks_lines(missing_dir)


def test_an_agent_file_with_an_empty_check_list_is_no_agent_checks(tmp_path, monkeypatch):
    monkeypatch.setenv("SBX_NAME", "sbx1")
    (tmp_path / "agent1.py").write_text("CHECK_LIST = []\n")

    status, line_list = run_lines([passing_check("check1")], tmp_path)

    assert status == 1
    assert line_list == expected_no_agent_checks_lines(tmp_path)


def test_a_broken_agent_file_alone_is_one_load_failure(tmp_path, monkeypatch):
    monkeypatch.setenv("SBX_NAME", "sbx1")
    (tmp_path / "agent1.py").write_text("def broken(:\n")

    status, line_list = run_lines([passing_check("check1")], tmp_path)

    fail_line_list = []

    for line in line_list:
        if line.startswith("FAIL: "):
            fail_line_list.append(line)

        assert "load-agent-checks" not in line

    assert status == 1
    assert len(fail_line_list) == 1
    assert fail_line_list[0].startswith("FAIL: load-agent1: ")
    assert line_list[-1] == "sbx-selfcheck: 2 checks, 1 failed"


def test_an_empty_shared_list_prints_the_agent_lines_only(agents1):
    status, line_list = run_lines([], agents1)

    assert status == 0
    assert line_list == ["PASS: agent1: detail_agent1", "sbx-selfcheck: 1 checks, 0 failed"]


def test_an_agent_file_with_a_syntax_error_is_one_load_failure(tmp_path, monkeypatch):
    monkeypatch.setenv("SBX_NAME", "sbx1")
    (tmp_path / "agent1.py").write_text("def broken(:\n")
    write_agent_file(tmp_path, "agent2")

    status, line_list = run_lines([], tmp_path)

    assert status == 1
    assert line_list[0].startswith("FAIL: load-agent1: ")
    assert "did not load: SyntaxError" in line_list[0]
    assert "on the Mac run: sbx-upgrade sbx1" in line_list[1]
    assert line_list[2] == "PASS: agent2: detail_agent2"
    assert line_list[3] == "sbx-selfcheck: 2 checks, 1 failed"


def test_an_agent_file_without_a_check_list_is_one_load_failure(tmp_path):
    (tmp_path / "agent2.py").write_text("VALUE1 = 1\n")
    write_agent_file(tmp_path, "agent1")

    status, line_list = run_lines([], tmp_path)

    assert status == 1
    assert line_list[0] == "PASS: agent1: detail_agent1"
    assert line_list[1].startswith("FAIL: load-agent2: ")
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
def test_an_agent_file_with_a_malformed_check_list_is_one_load_failure(tmp_path, monkeypatch, check_list_text):
    monkeypatch.setenv("SBX_NAME", "sbx1")
    agent_file = tmp_path / "agent1.py"
    agent_file.write_text(check_list_text)

    status, line_list = run_lines([passing_check("check1")], tmp_path)

    assert status == 1
    assert line_list == [
        "PASS: check1: detail_check1",
        f"FAIL: load-agent1: {agent_file} defines a CHECK_LIST that is not a list of checks",
        "      fix: rebuild the image and recreate the sandbox: on the Mac run: sbx-upgrade sbx1",
        "sbx-selfcheck: 2 checks, 1 failed",
    ]


# ------------------------------------------------------------------------------
# Main and the launcher
# ------------------------------------------------------------------------------

def test_main_with_an_argument_exits_two_with_one_usage_line_on_stderr(tmp_path, capsys):
    status = sbx_selfcheck.main(["extra"], [passing_check("check1")], tmp_path)

    captured = capsys.readouterr()
    assert status == 2
    assert captured.out == ""
    assert captured.err == "Usage: sbx-selfcheck (no arguments)\n"


def test_main_without_arguments_runs_the_checks_on_stdout(agents1, capsys):
    status = sbx_selfcheck.main([], [passing_check("check1")], agents1)

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


# ------------------------------------------------------------------------------
# Hint builders and environment values
# ------------------------------------------------------------------------------

def test_hint_builders_name_the_sandbox_from_sbx_name(monkeypatch):
    monkeypatch.setenv("SBX_NAME", "sbx1")

    assert selfcheck_core.rebuild_hint() == "rebuild the image and recreate the sandbox: on the Mac run: sbx-upgrade sbx1"
    assert selfcheck_core.restart_hint() == "restart the sandbox: on the Mac run: sbx-stop sbx1, then sbx-start sbx1"
    assert selfcheck_core.start_hint().endswith("on the Mac run: sbx-start sbx1, then sbx-shell sbx1")
    assert selfcheck_core.shell_hint().endswith("on the Mac run: sbx-shell sbx1")


def test_hint_builders_say_name_when_sbx_name_is_unset_or_empty(monkeypatch):
    monkeypatch.delenv("SBX_NAME", raising=False)

    assert selfcheck_core.rebuild_hint().endswith("on the Mac run: sbx-upgrade NAME")
    assert "on the Mac run: sbx-" in selfcheck_core.restart_hint()
    assert "on the Mac run: sbx-" in selfcheck_core.start_hint()
    assert "on the Mac run: sbx-" in selfcheck_core.shell_hint()

    monkeypatch.setenv("SBX_NAME", "")

    assert selfcheck_core.shell_hint().endswith("sbx-shell NAME")


def test_environment_values_result_passes_for_a_matching_mapping():
    result = selfcheck_core.environment_values_result(
        {"VAR1": "value1", "VAR2": "value2"},
        {"VAR1": "value1", "VAR2": "value2", "VAR3": "other"},
    )

    assert result.passed
    assert result.detail == "VAR1=value1, VAR2=value2"


def test_environment_values_result_names_each_wrong_or_missing_variable(monkeypatch):
    monkeypatch.setenv("SBX_NAME", "sbx1")

    result = selfcheck_core.environment_values_result(
        {"VAR1": "value1", "VAR2": "value2", "VAR3": "value3"},
        {"VAR1": "other1", "VAR3": "value3"},
    )

    assert not result.passed
    assert result.detail == "VAR1 is 'other1', expected 'value1'; VAR2 is not set"
    assert result.hint.endswith("on the Mac run: sbx-upgrade sbx1")


# ------------------------------------------------------------------------------
# Line format and base files
# ------------------------------------------------------------------------------

def test_every_line_is_pass_fail_fix_or_the_summary(tmp_path):
    (tmp_path / "agent1.py").write_text("raise RuntimeError('detail1')\n")
    write_agent_file(tmp_path, "agent2")
    check_list = [passing_check("check1"), failing_check("check2", "hint1")]

    status, line_list = run_lines(check_list, tmp_path)

    assert status == 1

    for line in line_list:
        assert line.startswith(("PASS: ", "FAIL: ", "      fix: ", "sbx-selfcheck: "))
        assert not line.startswith("SKIP")


def test_the_base_files_name_no_agent(repo_dir):
    base_dir = repo_dir / "base" / "selfcheck"

    for file_name in sorted(path.name for path in base_dir.iterdir() if path.suffix == ".py" or path.name == "sbx-selfcheck"):
        text = (base_dir / file_name).read_text().lower()

        assert "claude" not in text
        assert "cursor" not in text
