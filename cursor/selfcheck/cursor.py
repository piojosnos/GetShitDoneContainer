# The checks of the Cursor image. The image copies this file to
# /etc/sbx/selfcheck.d/cursor.py and the runner loads it after the shared checks.

from pathlib import Path

from sbx_selfcheck import Check, CheckResult, environment_values_result

CURSOR_CONFIG_DIR = Path("/home/sandbox/workspace/state/cursor")


def check_cursor_env() -> CheckResult:
    return environment_values_result({"CURSOR_CONFIG_DIR": str(CURSOR_CONFIG_DIR)})


CHECK_LIST = [
    Check("cursor-env", check_cursor_env),
]
