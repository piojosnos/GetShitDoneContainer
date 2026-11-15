# ------------------------------------------------------------------------------
# Tests of the pin readers
# ------------------------------------------------------------------------------

import hints
import pins
from helpers import TEMURIN_PIN1


# ------------------------------------------------------------------------------
# Pins
# ------------------------------------------------------------------------------

def test_parse_versions_text_skips_comments_and_blank_lines_and_splits_once():
    text = "# comment1\n\nNAME1=a=b\n  NAME2 = value2 \nbroken line\n"

    assert pins.parse_versions_text(text) == {"NAME1": "a=b", "NAME2": "value2"}


def test_pin_map_or_missing_reads_the_names_from_the_file(tmp_path):
    versions1 = tmp_path / "versions1"
    versions1.write_text("# comment1\n\nNAME1=a=b\nNAME2=c\n")

    pin_map, missing_result = pins.pin_map_or_missing(["NAME1", "NAME2"], versions1)

    assert pin_map == {"NAME1": "a=b", "NAME2": "c"}
    assert missing_result is None


def test_pin_map_or_missing_names_the_first_missing_name_or_file(tmp_path):
    versions1 = tmp_path / "versions1"
    versions1.write_text("NAME1=a\n")

    pin_map, missing_result = pins.pin_map_or_missing(["NAME1", "NAME2"], versions1)
    _, missing_file_result = pins.pin_map_or_missing(["NAME1"], tmp_path / "missing1")

    assert pin_map == {}
    assert missing_result.detail.startswith("NAME2 is not in ")
    assert missing_file_result.detail.startswith("NAME1 is not in ")


def test_missing_pin_result_fails_with_the_mac_rebuild_command():
    result = pins.missing_pin_result("NAME1")

    assert not result.passed
    assert "NAME1" in result.detail
    assert result.hint == hints.rebuild_hint()


def test_image_tag_takes_the_text_after_the_last_colon_before_the_digest():
    assert pins.image_tag("ghcr.io/astral-sh/uv:0.12.21@sha256:abc") == "0.12.21"
    assert pins.image_tag(TEMURIN_PIN1) == "21.0.12_8-jdk-noble"
    assert pins.image_tag("registry1:5000/image1:1.2@sha256:abc") == "1.2"


def test_jdk_version_is_the_tag_up_to_its_first_underscore():
    assert pins.jdk_version(TEMURIN_PIN1) == "21.0.12"
