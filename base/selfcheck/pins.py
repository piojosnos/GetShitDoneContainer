# --------------------------------------------------------------------------------
# The pins of the image
# --------------------------------------------------------------------------------
# /etc/sbx/versions.env holds one NAME=value pin per line. The image puts this
# file in /usr/local/lib/sbx-selfcheck/.
# --------------------------------------------------------------------------------

from pathlib import Path

from check_result import CheckResult, failed
from hints import rebuild_hint
from paths import VERSIONS_FILE


# --------------------------------------------------------------------------------
# Reading pins
# --------------------------------------------------------------------------------

def parse_versions_text(text: str) -> dict[str, str]:
    value_by_name_map = {}

    for line in text.splitlines():
        stripped_line = line.strip()

        if not stripped_line or stripped_line.startswith("#"):
            continue

        name, separator, value = stripped_line.partition("=")

        if not separator:
            continue

        value_by_name_map[name.strip()] = value.strip()

    return value_by_name_map


def pin_value(name: str, versions_file: Path = VERSIONS_FILE) -> str:
    if not versions_file.is_file():
        return ""

    return parse_versions_text(versions_file.read_text()).get(name, "")


def missing_pin_result(name: str) -> CheckResult:
    return failed(f"{name} is not in {VERSIONS_FILE}", rebuild_hint())


def pin_map_or_missing(
    pin_name_list: list[str],
    versions_file: Path = VERSIONS_FILE,
) -> tuple[dict[str, str], CheckResult | None]:
    value_by_name_map = {}

    for name in pin_name_list:
        value = pin_value(name, versions_file)

        if not value:
            return {}, missing_pin_result(name)

        value_by_name_map[name] = value

    return value_by_name_map, None


# --------------------------------------------------------------------------------
# Parts of an image pin
# --------------------------------------------------------------------------------

def image_tag(image_pin: str) -> str:
    return image_pin.partition("@")[0].rpartition(":")[2]


def jdk_version(temurin_pin: str) -> str:
    return image_tag(temurin_pin).partition("_")[0]
