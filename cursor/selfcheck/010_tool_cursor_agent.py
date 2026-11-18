# ------------------------------------------------------------------------------
# Checks: cursor-agent is the pinned version and stays off the PATH
# ------------------------------------------------------------------------------
# The agent lives in the agents directory, off the PATH; its agent wrapper puts the
# directory first. The image copies this file to /etc/sbx/selfcheck.d/cursor/; the
# runner loads it after the shared checks.
# ------------------------------------------------------------------------------

import os
import shutil
import tempfile
from pathlib import Path
from typing import Mapping

from check_result import Check, CheckResult
from paths import AGENT_BIN_DIR
from pins import pin_map_or_missing
from tools import agent_path_environment, off_path_result, tool_result

_THROWAWAY_HOME_PREFIX = "sbx-selfcheck-cursor-"


# ------------------------------------------------------------------------------
# Cursor version and PATH
# ------------------------------------------------------------------------------

def cursor_version_result(
    expected_version: str,
    agent_bin_dir: Path = AGENT_BIN_DIR,
    environment_map: Mapping[str, str] = os.environ,
) -> CheckResult:
    throwaway_home = tempfile.mkdtemp(prefix=_THROWAWAY_HOME_PREFIX)

    try:
        cursor_environment_map = dict(environment_map)
        cursor_environment_map.pop("CURSOR_CONFIG_DIR", None)
        cursor_environment_map["HOME"] = throwaway_home

        return tool_result(
            "cursor-agent",
            ["--version"],
            expected_version,
            environment_map=agent_path_environment(agent_bin_dir, cursor_environment_map),
        )
    finally:
        shutil.rmtree(throwaway_home, ignore_errors=True)


def cursor_off_path_result(
    agent_bin_dir: Path = AGENT_BIN_DIR,
    environment_map: Mapping[str, str] = os.environ,
) -> CheckResult:
    return off_path_result("cursor-agent", agent_bin_dir, environment_map)


# ------------------------------------------------------------------------------
# Check entries
# ------------------------------------------------------------------------------

def _check_tool_cursor_agent() -> CheckResult:
    pin_map, missing_result = pin_map_or_missing(["CURSOR_AGENT_VERSION"])

    if missing_result:
        return missing_result

    return cursor_version_result(pin_map["CURSOR_AGENT_VERSION"])


def _check_cursor_off_path() -> CheckResult:
    return cursor_off_path_result()


CHECK_LIST = [
    Check("tool-cursor-agent", _check_tool_cursor_agent),
    Check("cursor-off-path", _check_cursor_off_path),
]
