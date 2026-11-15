# ------------------------------------------------------------------------------
# Check: node is the pinned version
# ------------------------------------------------------------------------------
# The image puts this file in /usr/local/lib/sbx-selfcheck/checks/.
# ------------------------------------------------------------------------------

from pathlib import Path

from check_result import Check, CheckResult
from paths import VERSIONS_FILE
from pins import pin_map_or_missing
from tools import tool_result


# ------------------------------------------------------------------------------
# Tool node
# ------------------------------------------------------------------------------

def tool_node_result(versions_file: Path = VERSIONS_FILE) -> CheckResult:
    pin_map, missing_result = pin_map_or_missing(["NODE_VERSION"], versions_file)

    if missing_result:
        return missing_result

    return tool_result("node", ["-v"], f"v{pin_map['NODE_VERSION']}")


# ------------------------------------------------------------------------------
# Check entries
# ------------------------------------------------------------------------------

def _check_tool_node() -> CheckResult:
    return tool_node_result()


CHECK_LIST = [Check("tool-node", _check_tool_node)]
