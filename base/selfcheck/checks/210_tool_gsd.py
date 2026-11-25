# --------------------------------------------------------------------------------
# Check: gsd-tools is the pinned GSD version
# --------------------------------------------------------------------------------
# The image puts this file in /usr/local/lib/sbx-selfcheck/checks/.
# --------------------------------------------------------------------------------

from pathlib import Path

from check_result import Check, CheckResult
from paths import VERSIONS_FILE
from pins import pin_map_or_missing
from tools import tool_result


# --------------------------------------------------------------------------------
# Tool gsd
# --------------------------------------------------------------------------------

def tool_gsd_result(versions_file: Path = VERSIONS_FILE) -> CheckResult:
    pin_map, missing_result = pin_map_or_missing(["GSD_CORE_VERSION"], versions_file)

    if missing_result:
        return missing_result

    return tool_result(
        "gsd-tools",
        ["runtime-identity", "--raw"],
        '{"packageName":"@opengsd/gsd-core","version":"' + pin_map["GSD_CORE_VERSION"] + '"}',
    )


# --------------------------------------------------------------------------------
# Check entries
# --------------------------------------------------------------------------------

def _check_tool_gsd() -> CheckResult:
    return tool_gsd_result()


CHECK_LIST = [Check("tool-gsd", _check_tool_gsd)]
