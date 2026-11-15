# The shared checks of the environment variables. The image puts this file in
# /usr/local/lib/sbx-selfcheck/.

from pathlib import Path
from typing import Mapping

from selfcheck_core import (
    BUNDLE_DIR,
    VERSIONS_FILE,
    Check,
    CheckResult,
    environment_values_result,
    missing_pin_result,
    pin_value,
)

STATE_PATH_BY_NAME_MAP = {
    "HISTFILE": "/home/sandbox/workspace/state/shell/bash_history",
    "GH_CONFIG_DIR": "/home/sandbox/workspace/state/gh",
    "GIT_CONFIG_GLOBAL": "/home/sandbox/workspace/state/git/config",
    "NPM_CONFIG_CACHE": "/home/sandbox/workspace/state/cache/npm",
    "UV_CACHE_DIR": "/home/sandbox/workspace/state/cache/uv",
}


def bundle_env_result(
    versions_file: Path = VERSIONS_FILE,
    environment_map: Mapping[str, str] | None = None,
) -> CheckResult:
    pinned_url = pin_value("BUNDLE_REPO_URL", versions_file)

    if not pinned_url:
        return missing_pin_result("BUNDLE_REPO_URL")

    return environment_values_result(
        {"BUNDLE_REPO_URL": pinned_url, "SBX_BUNDLE_DIR": str(BUNDLE_DIR)},
        environment_map,
    )


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
