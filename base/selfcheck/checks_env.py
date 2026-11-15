# ------------------------------------------------------------------------------
# The shared checks of the environment variables
# ------------------------------------------------------------------------------
# The image puts this file in /usr/local/lib/sbx-selfcheck/.
# ------------------------------------------------------------------------------

import os
from pathlib import Path
from typing import Mapping

from selfcheck_core import (
    BUNDLE_DIR,
    STATE_DIR,
    VERSIONS_FILE,
    Check,
    CheckResult,
    environment_values_result,
    pin_map_or_missing,
)


# ------------------------------------------------------------------------------
# Constants
# ------------------------------------------------------------------------------

STATE_PATH_BY_NAME_MAP = {
    "HISTFILE": str(STATE_DIR / "shell" / "bash_history"),
    "GH_CONFIG_DIR": str(STATE_DIR / "gh"),
    "GIT_CONFIG_GLOBAL": str(STATE_DIR / "git" / "config"),
    "NPM_CONFIG_CACHE": str(STATE_DIR / "cache" / "npm"),
    "UV_CACHE_DIR": str(STATE_DIR / "cache" / "uv"),
}


# ------------------------------------------------------------------------------
# Environment checks
# ------------------------------------------------------------------------------

def bundle_env_result(
    versions_file: Path = VERSIONS_FILE,
    environment_map: Mapping[str, str] = os.environ,
) -> CheckResult:
    pin_map, missing_result = pin_map_or_missing(["BUNDLE_REPO_URL"], versions_file)

    if missing_result:
        return missing_result

    return environment_values_result(
        {"BUNDLE_REPO_URL": pin_map["BUNDLE_REPO_URL"], "SBX_BUNDLE_DIR": str(BUNDLE_DIR)},
        environment_map,
    )


# ------------------------------------------------------------------------------
# Check entries
# ------------------------------------------------------------------------------

def check_env_state_paths() -> CheckResult:
    return environment_values_result(STATE_PATH_BY_NAME_MAP)


def check_env_bundle() -> CheckResult:
    return bundle_env_result()


def check_java_home() -> CheckResult:
    return environment_values_result({"JAVA_HOME": "/opt/java/openjdk"})


ENV_CHECK_LIST = [
    Check("env-state-paths", check_env_state_paths),
    Check("env-bundle", check_env_bundle),
    Check("java-home", check_java_home),
]
