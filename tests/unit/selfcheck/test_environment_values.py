# --------------------------------------------------------------------------------
# Tests of the environment values result
# --------------------------------------------------------------------------------

import environment_values


# --------------------------------------------------------------------------------
# Environment values
# --------------------------------------------------------------------------------

def test_environment_values_result_passes_for_a_matching_mapping():
    result = environment_values.environment_values_result(
        {"VAR1": "value1", "VAR2": "value2"},
        {"VAR1": "value1", "VAR2": "value2", "VAR3": "other"},
    )

    assert result.passed
    assert result.detail == "VAR1=value1, VAR2=value2"


def test_environment_values_result_names_each_wrong_or_missing_variable():
    result = environment_values.environment_values_result(
        {"VAR1": "value1", "VAR2": "value2", "VAR3": "value3"},
        {"VAR1": "other1", "VAR3": "value3", "SBX_NAME": "sbx1"},
    )

    assert not result.passed
    assert result.detail == "VAR1 is 'other1', expected 'value1'; VAR2 is not set"
    assert result.hint.endswith("on the host run: sbx-upgrade sbx1")
