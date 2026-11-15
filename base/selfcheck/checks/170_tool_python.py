# ------------------------------------------------------------------------------
# Check: python3 is the version that runs the checks
# ------------------------------------------------------------------------------
# The image puts this file in /usr/local/lib/sbx-selfcheck/checks/.
# ------------------------------------------------------------------------------

import platform

from check_result import Check, CheckResult
from tools import tool_result


# ------------------------------------------------------------------------------
# Tool python
# ------------------------------------------------------------------------------

def _tool_python_result() -> CheckResult:
    return tool_result("python3", ["--version"], f"Python {platform.python_version()}")


# ------------------------------------------------------------------------------
# Check entries
# ------------------------------------------------------------------------------

def _check_tool_python() -> CheckResult:
    return _tool_python_result()


CHECK_LIST = [Check("tool-python", _check_tool_python)]
