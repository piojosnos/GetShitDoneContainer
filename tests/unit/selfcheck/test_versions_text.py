# --------------------------------------------------------------------------------
# Tests of the versions line text
# --------------------------------------------------------------------------------

import platform

import pytest

import versions_text


# --------------------------------------------------------------------------------
# Constants and helpers
# --------------------------------------------------------------------------------

BASE_VERSIONS_TEXT1 = "gsd 1.15.0 | node 24.21.0 | jdk 21.0.12 | mvn 3.9.11 | python 3.12.3"


# --------------------------------------------------------------------------------
# Versions line text
# --------------------------------------------------------------------------------

def test_expected_base_versions_text_is_built_from_the_pins_and_the_python_version(versions1):
    assert versions_text.expected_base_versions_text(versions1, "3.12.3") == BASE_VERSIONS_TEXT1


# --------------------------------------------------------------------------------

def test_expected_base_versions_text_uses_the_running_python_by_default(versions1):
    text = versions_text.expected_base_versions_text(versions1)

    assert text.endswith(f"| python {platform.python_version()}")


# --------------------------------------------------------------------------------

def test_expected_base_versions_text_names_the_missing_pin(tmp_path, versions1):
    versions2 = tmp_path / "versions2.env"
    versions2.write_text(versions1.read_text().replace("MAVEN_VERSION=3.9.11\n", ""))

    with pytest.raises(KeyError, match="MAVEN_VERSION"):
        versions_text.expected_base_versions_text(versions2, "3.12.3")


# --------------------------------------------------------------------------------

def test_versions_line_result_passes_for_the_prefix_and_the_base_text(versions1, line1):
    line1.write_text("tool1 1 | " + versions_text.expected_base_versions_text(versions1) + "\n")

    result = versions_text.versions_line_result("tool1 1 | ", line1, versions1)

    assert result.passed


# --------------------------------------------------------------------------------

def test_versions_line_result_fails_when_one_field_differs(versions1, line1):
    line1.write_text("tool1 1 | " + versions_text.expected_base_versions_text(versions1).replace("node 24.21.0", "node 24.21.1") + "\n")

    result = versions_text.versions_line_result("tool1 1 | ", line1, versions1)

    assert not result.passed
    assert "node 24.21.1" in result.detail
    assert "node 24.21.0" in result.detail
    assert "sbx-upgrade" in result.hint


# --------------------------------------------------------------------------------

def test_versions_line_result_fails_when_the_file_holds_two_lines(versions1, line1):
    base_text = versions_text.expected_base_versions_text(versions1)
    line1.write_text("tool1 1 | " + base_text + "\n" + "tool1 1 | " + base_text + "\n")

    assert not versions_text.versions_line_result("tool1 1 | ", line1, versions1).passed


# --------------------------------------------------------------------------------

def test_versions_line_result_fails_when_the_file_is_missing(tmp_path, versions1):
    result = versions_text.versions_line_result("tool1 1 | ", tmp_path / "missing1", versions1)

    assert not result.passed
    assert "missing1" in result.detail


# --------------------------------------------------------------------------------

def test_versions_line_result_reports_a_missing_pin(tmp_path, line1):
    empty_versions = tmp_path / "empty1.env"
    empty_versions.write_text("")
    line1.write_text("anything\n")

    result = versions_text.versions_line_result("tool1 1 | ", line1, empty_versions)

    assert not result.passed
    assert result.detail.startswith("GSD_CORE_VERSION is not in ")
