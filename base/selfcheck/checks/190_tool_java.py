# ------------------------------------------------------------------------------
# Check: java is the pinned Temurin JDK
# ------------------------------------------------------------------------------
# The image puts this file in /usr/local/lib/sbx-selfcheck/checks/.
# ------------------------------------------------------------------------------

from pathlib import Path

from check_result import Check, CheckResult
from paths import VERSIONS_FILE
from pins import jdk_version, pin_map_or_missing
from tools import tool_result


# ------------------------------------------------------------------------------
# Tool java
# ------------------------------------------------------------------------------

def tool_java_result(versions_file: Path = VERSIONS_FILE) -> CheckResult:
    pin_map, missing_result = pin_map_or_missing(["TEMURIN_IMAGE"], versions_file)

    if missing_result:
        return missing_result

    return tool_result(
        "java", ["-version"], f'openjdk version "{jdk_version(pin_map["TEMURIN_IMAGE"])}"', required_text="Temurin"
    )


# ------------------------------------------------------------------------------
# Check entries
# ------------------------------------------------------------------------------

def _check_tool_java() -> CheckResult:
    return tool_java_result()


CHECK_LIST = [Check("tool-java", _check_tool_java)]
