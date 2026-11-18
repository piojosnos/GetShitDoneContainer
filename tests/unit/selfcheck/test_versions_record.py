# ------------------------------------------------------------------------------
# Tests of the versions record check
# ------------------------------------------------------------------------------

from helpers import load_shared_check

versions_record = load_shared_check("230_versions_record")


# ------------------------------------------------------------------------------
# Versions record
# ------------------------------------------------------------------------------

def test_versions_record_passes_when_every_shared_pin_has_a_value(versions1):
    result = versions_record.versions_record_result(versions1)

    assert result.passed
    assert str(versions1) in result.detail


def test_versions_record_names_the_pins_that_are_missing_or_empty(tmp_path, versions1):
    versions2 = tmp_path / "versions2.env"
    versions2.write_text(versions1.read_text().replace("GH_VERSION=2.102.0", "GH_VERSION=").replace("NODE_VERSION=24.21.0\n", ""))

    result = versions_record.versions_record_result(versions2)

    assert not result.passed
    assert "GH_VERSION" in result.detail
    assert "NODE_VERSION" in result.detail
    assert "MAVEN_VERSION" not in result.detail


def test_versions_record_fails_when_the_file_is_missing(tmp_path):
    result = versions_record.versions_record_result(tmp_path / "missing1.env")

    assert not result.passed
    assert "missing1.env" in result.detail


def test_versions_record_does_not_run_what_the_file_holds(tmp_path, versions1):
    marker1 = tmp_path / "marker1"
    versions2 = tmp_path / "versions2.env"
    versions2.write_text(versions1.read_text() + f"GH_VERSION=$(touch {marker1})\n")

    versions_record.versions_record_result(versions2)

    assert not marker1.exists()
