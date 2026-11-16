# ------------------------------------------------------------------------------
# Tests of the result builders
# ------------------------------------------------------------------------------

import pytest

import check_result


# ------------------------------------------------------------------------------
# Result builders
# ------------------------------------------------------------------------------

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
