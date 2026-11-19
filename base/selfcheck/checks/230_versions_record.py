# ------------------------------------------------------------------------------
# Check: the versions record holds every shared pin
# ------------------------------------------------------------------------------
# The image puts this file in /usr/local/lib/sbx-selfcheck/checks/.
# ------------------------------------------------------------------------------

from pathlib import Path

from check_result import Check, CheckResult, failed, passed
from hints import rebuild_hint
from paths import VERSIONS_FILE
from pins import parse_versions_text

_SHARED_PIN_NAME_LIST = [
    "GH_VERSION",
    "NODE_VERSION",
    "MAVEN_VERSION",
    "GSD_CORE_VERSION",
    "TEMURIN_IMAGE",
    "UV_IMAGE",
    "BEST_PRACTICES_REPO_URL",
]


# ------------------------------------------------------------------------------
# Versions record
# ------------------------------------------------------------------------------

def versions_record_result(versions_file: Path = VERSIONS_FILE) -> CheckResult:
    if not versions_file.is_file():
        return failed(f"{versions_file} is missing", rebuild_hint())

    value_by_name_map = parse_versions_text(versions_file.read_text())
    missing_list = []

    for name in _SHARED_PIN_NAME_LIST:
        if not value_by_name_map.get(name):
            missing_list.append(name)

    if missing_list:
        return failed(f"{', '.join(missing_list)} missing or empty in {versions_file}", rebuild_hint())

    return passed(f"{len(value_by_name_map)} pins in {versions_file}")


# ------------------------------------------------------------------------------
# Check entries
# ------------------------------------------------------------------------------

def _check_versions_record() -> CheckResult:
    return versions_record_result()


CHECK_LIST = [Check("versions-record", _check_versions_record)]
