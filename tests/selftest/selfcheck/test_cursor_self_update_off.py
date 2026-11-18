# ------------------------------------------------------------------------------
# Tests of the Cursor self-update check
# ------------------------------------------------------------------------------
# Real files inside tmp_path.
# ------------------------------------------------------------------------------

import json

import hints
from helpers import load_agent_check

self_update_off = load_agent_check("cursor", "050_self_update_off")


# ------------------------------------------------------------------------------
# Self-update
# ------------------------------------------------------------------------------

def test_self_update_result_passes_for_the_static_channel_and_names_no_other_key(tmp_path):
    config_file1 = tmp_path / "cli-config1.json"
    config_file1.write_text(json.dumps({"channel": "static", "other1": 1}))

    result = self_update_off.self_update_result(config_file1)

    assert result.passed
    assert "static" in result.detail
    assert "other1" not in result.detail + result.hint


def test_self_update_result_fails_for_another_channel_bad_text_and_a_missing_file(tmp_path):
    stable1 = tmp_path / "stable1.json"
    stable1.write_text(json.dumps({"channel": "stable", "other1": 1}))
    text1 = tmp_path / "text1.json"
    text1.write_text("not json {")
    list1 = tmp_path / "list1.json"
    list1.write_text("[1]")

    stable_result = self_update_off.self_update_result(stable1)
    text_result = self_update_off.self_update_result(text1)
    list_result = self_update_off.self_update_result(list1)
    missing_result = self_update_off.self_update_result(tmp_path / "missing1.json")

    assert "stable" in stable_result.detail
    assert "other1" not in stable_result.detail

    for result in [stable_result, text_result, list_result, missing_result]:
        assert not result.passed
        assert result.hint == hints.init_hint()
