# The checks of the Claude image. The image copies this file to
# /etc/sbx/selfcheck.d/claude.py and the runner loads it after the shared checks.

from pathlib import Path

from sbx_selfcheck import Check, CheckResult, environment_values_result

CLAUDE_CONFIG_DIR = Path("/home/sandbox/workspace/state/claude")


def check_claude_env() -> CheckResult:
    return environment_values_result({"CLAUDE_CONFIG_DIR": str(CLAUDE_CONFIG_DIR), "DISABLE_UPDATES": "1"})


CHECK_LIST = [
    Check("claude-env", check_claude_env),
]
