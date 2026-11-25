# --------------------------------------------------------------------------------
# Tests of the result builders
# --------------------------------------------------------------------------------

import pytest

import check_result
import hints


# --------------------------------------------------------------------------------
# Result builders
# --------------------------------------------------------------------------------

def test_failed_refuses_an_empty_or_blank_hint():
    with pytest.raises(ValueError):
        check_result.failed("detail1", "")

    with pytest.raises(ValueError):
        check_result.failed("detail1", "   ")


def test_problem_list_result_joins_the_problems_into_one_failure():
    result = check_result.problem_list_result(["problem1", "problem2"], "hint1", "all fine")

    assert not result.passed
    assert result.detail == "problem1; problem2"
    assert result.hint == "hint1"


def test_problem_list_result_passes_with_the_passed_detail_when_there_is_no_problem():
    result = check_result.problem_list_result([], "hint1", "all fine")

    assert result.passed
    assert result.detail == "all fine"


def test_one_line_turns_line_breaks_into_spaces():
    assert check_result.one_line("a\r\nb\nc") == "a  b c"


# --------------------------------------------------------------------------------
# Capped lists
# --------------------------------------------------------------------------------

def test_capped_list_text_keeps_the_first_ten_items_by_default():
    item_list = [f"item{number}" for number in range(12)]

    assert check_result.capped_list_text(item_list, ", ") == ", ".join(item_list[:10])
    assert check_result.capped_list_text(item_list, "; ", 2) == "item0; item1"
    assert check_result.capped_list_text([], ", ") == ""


def test_capped_problem_detail_counts_every_problem_and_lists_the_first_ten():
    problem_list = [f"problem{number}" for number in range(12)]

    assert check_result.capped_problem_detail(problem_list) == "12 problems: " + "; ".join(problem_list[:10])


# --------------------------------------------------------------------------------
# Making a state directory
# --------------------------------------------------------------------------------

def test_make_state_dir_makes_nested_dirs_and_accepts_an_existing_one(tmp_path):
    dir1 = tmp_path / "a" / "b"

    assert check_result.make_state_dir(dir1) is None
    assert dir1.is_dir()
    assert check_result.make_state_dir(dir1) is None


def test_make_state_dir_fails_under_a_plain_file_with_the_writable_hint(tmp_path):
    blocker1 = tmp_path / "blocker1"
    blocker1.write_text("a file where a directory is needed")

    result = check_result.make_state_dir(blocker1 / "dir1")

    assert result is not None
    assert not result.passed
    assert result.detail.startswith(f"cannot make {blocker1 / 'dir1'}: ")
    assert result.hint == hints.state_writable_hint()
