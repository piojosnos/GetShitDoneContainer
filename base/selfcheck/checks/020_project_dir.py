# --------------------------------------------------------------------------------
# Check: the project directory exists in the workspace
# --------------------------------------------------------------------------------
# The image puts this file in /usr/local/lib/sbx-selfcheck/checks/.
# --------------------------------------------------------------------------------

import os
from pathlib import Path

from check_result import Check, CheckResult, failed, passed
from hints import host_hint, sandbox_name
from paths import WORKSPACE_DIR


# --------------------------------------------------------------------------------
# Project directory
# --------------------------------------------------------------------------------

def project_dir_result(workspace_dir: Path, project_name: str) -> CheckResult:
    start_text = host_hint("start the sandbox with sbx-start, which checks the project directory", f"sbx-start {sandbox_name()}")

    if not project_name:
        return failed("SBX_NAME is not set", start_text)

    project_dir = workspace_dir / project_name

    if not project_dir.is_dir():
        return failed(f"{project_dir} (the project directory) is missing", start_text)

    return passed(f"{project_dir} exists")


# --------------------------------------------------------------------------------
# Check entries
# --------------------------------------------------------------------------------

def _check_project_dir() -> CheckResult:
    return project_dir_result(WORKSPACE_DIR, os.environ.get("SBX_NAME", ""))


CHECK_LIST = [Check("project-dir", _check_project_dir)]
