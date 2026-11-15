# ------------------------------------------------------------------------------
# Check: the state variables point into the state folder
# ------------------------------------------------------------------------------
# The image puts this file in /usr/local/lib/sbx-selfcheck/checks/.
# ------------------------------------------------------------------------------

from check_result import Check, CheckResult
from environment_values import environment_values_result
from paths import STATE_DIR

_STATE_PATH_BY_NAME_MAP = {
    "HISTFILE": str(STATE_DIR / "shell" / "bash_history"),
    "GH_CONFIG_DIR": str(STATE_DIR / "gh"),
    "GIT_CONFIG_GLOBAL": str(STATE_DIR / "git" / "config"),
    "NPM_CONFIG_CACHE": str(STATE_DIR / "cache" / "npm"),
    "UV_CACHE_DIR": str(STATE_DIR / "cache" / "uv"),
}


# ------------------------------------------------------------------------------
# Check entries
# ------------------------------------------------------------------------------

def _check_env_state_paths() -> CheckResult:
    return environment_values_result(_STATE_PATH_BY_NAME_MAP)


CHECK_LIST = [Check("env-state-paths", _check_env_state_paths)]
