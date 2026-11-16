# ------------------------------------------------------------------------------
# Check: cursor-agent is the pinned version
# ------------------------------------------------------------------------------
# The image copies this file to /etc/sbx/selfcheck.d/cursor/; the runner loads it
# after the shared checks.
# ------------------------------------------------------------------------------

import os
import shutil
import tempfile
from typing import Mapping

from check_result import Check, CheckResult
from pins import pin_map_or_missing
from tools import tool_result

_THROWAWAY_HOME_PREFIX = "sbx-selfcheck-cursor-"


# ------------------------------------------------------------------------------
# Cursor version
# ------------------------------------------------------------------------------

def cursor_version_result(expected_version: str, environment_map: Mapping[str, str] = os.environ) -> CheckResult:
    throwaway_home = tempfile.mkdtemp(prefix=_THROWAWAY_HOME_PREFIX)

    try:
        cursor_environment_map = dict(environment_map)
        cursor_environment_map.pop("CURSOR_CONFIG_DIR", None)
        cursor_environment_map["HOME"] = throwaway_home

        return tool_result("cursor-agent", ["--version"], expected_version, environment_map=cursor_environment_map)
    finally:
        shutil.rmtree(throwaway_home, ignore_errors=True)


# ------------------------------------------------------------------------------
# Check entries
# ------------------------------------------------------------------------------

def _check_tool_cursor_agent() -> CheckResult:
    pin_map, missing_result = pin_map_or_missing(["CURSOR_AGENT_VERSION"])

    if missing_result:
        return missing_result

    return cursor_version_result(pin_map["CURSOR_AGENT_VERSION"])


CHECK_LIST = [Check("tool-cursor-agent", _check_tool_cursor_agent)]
