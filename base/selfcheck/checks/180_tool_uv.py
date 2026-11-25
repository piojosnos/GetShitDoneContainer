# --------------------------------------------------------------------------------
# Check: uv is the pinned version
# --------------------------------------------------------------------------------
# The image puts this file in /usr/local/lib/sbx-selfcheck/checks/.
# --------------------------------------------------------------------------------

from pathlib import Path

from check_result import Check, CheckResult
from paths import VERSIONS_FILE
from pins import image_tag, pin_map_or_missing
from tools import tool_result


# --------------------------------------------------------------------------------
# Tool uv
# --------------------------------------------------------------------------------

def tool_uv_result(versions_file: Path = VERSIONS_FILE) -> CheckResult:
    pin_map, missing_result = pin_map_or_missing(["UV_IMAGE"], versions_file)

    if missing_result:
        return missing_result

    return tool_result("uv", ["--version"], f"uv {image_tag(pin_map['UV_IMAGE'])}")


# --------------------------------------------------------------------------------
# Check entries
# --------------------------------------------------------------------------------

def _check_tool_uv() -> CheckResult:
    return tool_uv_result()


CHECK_LIST = [Check("tool-uv", _check_tool_uv)]
