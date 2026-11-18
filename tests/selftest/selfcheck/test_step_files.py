# ------------------------------------------------------------------------------
# Tests of the shared step file code
# ------------------------------------------------------------------------------
# They use an abstract kind and step files written into tmp_path.
# ------------------------------------------------------------------------------

import io
from pathlib import Path

import pytest

import step_files
from check_result import Check, CheckResult, failed, passed
from hints import rebuild_hint

KIND1 = step_files.StepFileKind(
    list_name="ITEM_LIST1",
    item_word="items1",
    module_prefix="test_step_files_",
    owner_text="owner1",
    pass_word="WORD1",
)
FILE_TEXT_TEMPLATE = """from check_result import Check, passed


def run_item1():
    return passed("detail1")


{list_line}
"""


# ------------------------------------------------------------------------------
# Helpers
# ------------------------------------------------------------------------------

def write_raw_file(tmp_path: Path, text: str) -> Path:
    group_dir = tmp_path / "group1"
    group_dir.mkdir(exist_ok=True)
    module_path = group_dir / "010_file1.py"
    module_path.write_text(text)

    return module_path


def write_step_file(tmp_path: Path, list_line: str) -> Path:
    return write_raw_file(tmp_path, FILE_TEXT_TEMPLATE.format(list_line=list_line))


def only_check(check_list: list[Check]) -> Check:
    assert len(check_list) == 1

    return check_list[0]


# ------------------------------------------------------------------------------
# Loading a step file
# ------------------------------------------------------------------------------

def test_load_list_returns_the_list_named_by_the_kind(tmp_path):
    module_path = write_step_file(tmp_path, 'ITEM_LIST1 = [Check("item1", run_item1)]')

    check_list = step_files.load_list(module_path, KIND1)

    assert [check.name for check in check_list] == ["item1"]
    assert check_list[0].function() == passed("detail1")


def test_a_file_without_the_list_gives_one_load_failure_check(tmp_path):
    module_path = write_step_file(tmp_path, "")

    check = only_check(step_files.load_list(module_path, KIND1))

    assert check.name == "load-group1-010-file1"
    assert check.function() == failed(f"{module_path} defines no ITEM_LIST1", rebuild_hint())


def test_a_file_that_raises_at_import_gives_one_load_failure_check(tmp_path):
    module_path = write_raw_file(tmp_path, 'raise RuntimeError("detail1")\n')

    check = only_check(step_files.load_list(module_path, KIND1))

    assert check.name == "load-group1-010-file1"
    assert check.function() == failed(f"{module_path} did not load: RuntimeError: detail1", rebuild_hint())


def test_a_list_holding_a_non_check_gives_one_load_failure_check(tmp_path):
    module_path = write_step_file(tmp_path, 'ITEM_LIST1 = [Check("item1", run_item1), "text1"]')

    check = only_check(step_files.load_list(module_path, KIND1))

    expected_detail = f"{module_path} defines a ITEM_LIST1 that is not a list of items1"
    assert check.function() == failed(expected_detail, rebuild_hint())


def test_a_file_with_only_the_other_list_name_defines_no_list_of_this_kind(tmp_path):
    module_path = write_step_file(tmp_path, 'ITEM_LIST2 = [Check("item1", run_item1)]')

    check = only_check(step_files.load_list(module_path, KIND1))

    assert check.function() == failed(f"{module_path} defines no ITEM_LIST1", rebuild_hint())


def test_load_failure_check_reports_its_detail_and_the_rebuild_hint():
    check = step_files.load_failure_check("name1", "detail1")

    assert check.name == "name1"
    assert check.function() == failed("detail1", rebuild_hint())


# ------------------------------------------------------------------------------
# Running one entry
# ------------------------------------------------------------------------------

def return_passed() -> CheckResult:
    return passed("detail1")


def test_run_one_returns_a_passing_result_unchanged():
    check = Check("name1", return_passed)

    assert step_files.run_one(check, KIND1) == passed("detail1")


def raise_runtime_error() -> CheckResult:
    raise RuntimeError("detail1")


def return_text() -> str:
    return "text1"


@pytest.mark.parametrize(
    "function,expected_detail",
    [
        (raise_runtime_error, "raised RuntimeError: detail1"),
        (return_text, "returned str instead of a CheckResult"),
    ],
    ids=["raises", "wrong-type"],
)
def test_run_one_turns_a_broken_entry_into_a_fail_with_the_owner_hint(function, expected_detail):
    result = step_files.run_one(Check("name1", function), KIND1)

    assert result == failed(expected_detail, "this is a bug in owner1 or a broken image; " + rebuild_hint())


# ------------------------------------------------------------------------------
# Outcome lines
# ------------------------------------------------------------------------------

def test_a_pass_is_one_line_with_the_pass_word():
    assert step_files.outcome_lines("name1", passed("detail1"), KIND1) == ["WORD1: name1: detail1"]


def test_a_fail_is_a_fail_line_and_an_indented_fix_line():
    lines = step_files.outcome_lines("name1", failed("detail1", "hint1"), KIND1)

    assert lines == ["FAIL: name1: detail1", "      fix: hint1"]


def test_a_newline_or_carriage_return_becomes_a_space():
    lines = step_files.outcome_lines("name1", failed("a\nb\rc", "d\ne\rf"), KIND1)

    assert lines == ["FAIL: name1: a b c", "      fix: d e f"]


def test_write_outcome_writes_each_line_with_a_newline():
    output = io.StringIO()

    step_files.write_outcome(output, "name1", failed("detail1", "hint1"), KIND1)

    assert output.getvalue() == "FAIL: name1: detail1\n      fix: hint1\n"
