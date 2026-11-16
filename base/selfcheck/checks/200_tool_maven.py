# ------------------------------------------------------------------------------
# Check: mvn is the pinned version and runs on the pinned JDK
# ------------------------------------------------------------------------------
# The image puts this file in /usr/local/lib/sbx-selfcheck/checks/.
# ------------------------------------------------------------------------------

from pathlib import Path

from check_result import Check, CheckResult
from paths import VERSIONS_FILE
from pins import jdk_version, pin_map_or_missing
from tools import tool_result


# ------------------------------------------------------------------------------
# Tool maven
# ------------------------------------------------------------------------------

def tool_maven_result(versions_file: Path = VERSIONS_FILE) -> CheckResult:
    pin_map, missing_result = pin_map_or_missing(["MAVEN_VERSION", "TEMURIN_IMAGE"], versions_file)

    if missing_result:
        return missing_result

    return tool_result(
        "mvn",
        ["-v"],
        f"Apache Maven {pin_map['MAVEN_VERSION']}",
        required_text=f"Java version: {jdk_version(pin_map['TEMURIN_IMAGE'])},",
    )


# ------------------------------------------------------------------------------
# Check entries
# ------------------------------------------------------------------------------

def _check_tool_maven() -> CheckResult:
    return tool_maven_result()


CHECK_LIST = [Check("tool-maven", _check_tool_maven)]
