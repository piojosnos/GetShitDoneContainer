# --------------------------------------------------------------------------------
# Check: the best-practices environment matches the pin and the clone
# --------------------------------------------------------------------------------
# The image puts this file in /usr/local/lib/sbx-selfcheck/checks/.
# --------------------------------------------------------------------------------

import os
from pathlib import Path
from typing import Mapping

from check_result import Check, CheckResult
from environment_values import environment_values_result
from paths import BEST_PRACTICES_DIR, VERSIONS_FILE
from pins import pin_map_or_missing


# --------------------------------------------------------------------------------
# Best-practices environment
# --------------------------------------------------------------------------------

def best_practices_env_result(
    versions_file: Path = VERSIONS_FILE,
    environment_map: Mapping[str, str] = os.environ,
) -> CheckResult:
    pin_map, missing_result = pin_map_or_missing(["BEST_PRACTICES_REPO_URL"], versions_file)

    if missing_result:
        return missing_result

    return environment_values_result(
        {"BEST_PRACTICES_REPO_URL": pin_map["BEST_PRACTICES_REPO_URL"], "SBX_BEST_PRACTICES_DIR": str(BEST_PRACTICES_DIR)},
        environment_map,
    )


# --------------------------------------------------------------------------------
# Check entries
# --------------------------------------------------------------------------------

def _check_env_best_practices() -> CheckResult:
    return best_practices_env_result()


CHECK_LIST = [Check("env-best-practices", _check_env_best_practices)]
