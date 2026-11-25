# --------------------------------------------------------------------------------
# Checks: the tools with no pinned version
# --------------------------------------------------------------------------------
# The image puts this file in /usr/local/lib/sbx-selfcheck/checks/.
# --------------------------------------------------------------------------------

from check_result import Check, CheckResult
from tools import tool_result

_PLAIN_TOOL_NAME_LIST = ["git", "bash", "keytool", "jq", "rg", "unzip", "zip", "ssh", "make", "gcc"]


# --------------------------------------------------------------------------------
# Plain tool checks
# --------------------------------------------------------------------------------

def _plain_tool_check(command_name: str) -> Check:
    def run_tool_check() -> CheckResult:
        return tool_result(command_name)

    return Check("tool-" + command_name, run_tool_check)


# --------------------------------------------------------------------------------
# Check entries
# --------------------------------------------------------------------------------

CHECK_LIST = []

for tool_name in _PLAIN_TOOL_NAME_LIST:
    CHECK_LIST.append(_plain_tool_check(tool_name))
