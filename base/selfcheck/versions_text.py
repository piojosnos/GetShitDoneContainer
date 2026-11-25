# --------------------------------------------------------------------------------
# The versions line of an image
# --------------------------------------------------------------------------------
# /etc/sbx/tool-versions holds the line a shell prints. The base fields come
# from the pins; an agent image puts its own fields in front. The image puts this
# file in /usr/local/lib/sbx-selfcheck/.
# --------------------------------------------------------------------------------

import platform
from pathlib import Path

from check_result import CheckResult, failed, one_line, passed
from hints import rebuild_hint
from paths import TOOL_VERSIONS_FILE, VERSIONS_FILE
from pins import jdk_version, missing_pin_result, pin_value


# --------------------------------------------------------------------------------
# The expected line
# --------------------------------------------------------------------------------

def expected_base_versions_text(versions_file: Path = VERSIONS_FILE, python_version: str | None = None) -> str:
    if python_version is None:
        python_version = platform.python_version()

    gsd_version = pin_value("GSD_CORE_VERSION", versions_file)
    node_version = pin_value("NODE_VERSION", versions_file)
    temurin_image = pin_value("TEMURIN_IMAGE", versions_file)
    maven_version = pin_value("MAVEN_VERSION", versions_file)

    for name, value in [
        ("GSD_CORE_VERSION", gsd_version),
        ("NODE_VERSION", node_version),
        ("TEMURIN_IMAGE", temurin_image),
        ("MAVEN_VERSION", maven_version),
    ]:
        if not value:
            raise KeyError(name)

    return (
        f"gsd {gsd_version} | node {node_version} | jdk {jdk_version(temurin_image)}"
        f" | mvn {maven_version} | python {python_version}"
    )


# --------------------------------------------------------------------------------
# The line of an agent image
# --------------------------------------------------------------------------------

def versions_line_result(
    prefix_text: str,
    versions_line_file: Path = TOOL_VERSIONS_FILE,
    versions_file: Path = VERSIONS_FILE,
) -> CheckResult:
    try:
        expected_line = prefix_text + expected_base_versions_text(versions_file)
    except KeyError as e:
        return missing_pin_result(e.args[0])

    if not versions_line_file.is_file():
        return failed(f"{versions_line_file} is missing", rebuild_hint())

    actual_text = versions_line_file.read_text()

    if actual_text != expected_line + "\n":
        return failed(
            f"{versions_line_file} holds '{one_line(actual_text.rstrip())}'; expected '{expected_line}'",
            rebuild_hint(),
        )

    return passed(f"the line is {expected_line}")
