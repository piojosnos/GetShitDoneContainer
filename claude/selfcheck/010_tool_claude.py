# --------------------------------------------------------------------------------
# Checks: claude is the pinned version and stays off the PATH
# --------------------------------------------------------------------------------
# The agent lives in the agents directory, off the PATH; its agent wrapper puts the
# directory first. The image copies this file to /etc/sbx/selfcheck.d/claude/; the
# runner loads it after the shared checks.
# --------------------------------------------------------------------------------

import os
from pathlib import Path
from typing import Mapping

from check_result import Check, CheckResult
from paths import AGENT_BIN_DIR
from pins import pin_map_or_missing
from tools import agent_path_environment, off_path_result, tool_result


# --------------------------------------------------------------------------------
# Claude version and PATH
# --------------------------------------------------------------------------------

def claude_version_result(
    expected_version: str,
    agent_bin_dir: Path = AGENT_BIN_DIR,
    environment_map: Mapping[str, str] = os.environ,
) -> CheckResult:
    return tool_result(
        "claude",
        ["--version"],
        f"{expected_version} (Claude Code)",
        environment_map=agent_path_environment(agent_bin_dir, environment_map),
    )


def claude_off_path_result(
    agent_bin_dir: Path = AGENT_BIN_DIR,
    environment_map: Mapping[str, str] = os.environ,
) -> CheckResult:
    return off_path_result("claude", agent_bin_dir, environment_map)


# --------------------------------------------------------------------------------
# Check entries
# --------------------------------------------------------------------------------

def _check_tool_claude() -> CheckResult:
    pin_map, missing_result = pin_map_or_missing(["CLAUDE_CODE_VERSION"])

    if missing_result:
        return missing_result

    return claude_version_result(pin_map["CLAUDE_CODE_VERSION"])


def _check_claude_off_path() -> CheckResult:
    return claude_off_path_result()


CHECK_LIST = [
    Check("tool-claude", _check_tool_claude),
    Check("claude-off-path", _check_claude_off_path),
]
