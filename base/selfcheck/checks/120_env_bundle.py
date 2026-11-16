# ------------------------------------------------------------------------------
# Check: the bundle variables match the pin and the clone
# ------------------------------------------------------------------------------
# The image puts this file in /usr/local/lib/sbx-selfcheck/checks/.
# ------------------------------------------------------------------------------

import os
from pathlib import Path
from typing import Mapping

from check_result import Check, CheckResult
from environment_values import environment_values_result
from paths import BUNDLE_DIR, VERSIONS_FILE
from pins import pin_map_or_missing


# ------------------------------------------------------------------------------
# Bundle variables
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

def _check_env_bundle() -> CheckResult:
    return bundle_env_result()


CHECK_LIST = [Check("env-bundle", _check_env_bundle)]
