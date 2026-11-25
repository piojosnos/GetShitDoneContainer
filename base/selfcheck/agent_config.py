# --------------------------------------------------------------------------------
# What an agent keeps in its config directory
# --------------------------------------------------------------------------------
# The login file and the GSD copy sbx-init syncs. The image puts this file in
# /usr/local/lib/sbx-selfcheck/.
# --------------------------------------------------------------------------------

from pathlib import Path

from check_result import CheckResult, failed, passed
from hints import init_hint
from paths import VERSIONS_FILE
from pins import pin_map_or_missing


# --------------------------------------------------------------------------------
# Login file
# --------------------------------------------------------------------------------

def login_file_result(login_file: Path, login_hint: str) -> CheckResult:
    if not login_file.is_file() or login_file.stat().st_size == 0:
        return failed(f"{login_file} is missing or empty", login_hint)

    return passed(f"{login_file} is there ({login_file.stat().st_size} bytes)")


# --------------------------------------------------------------------------------
# GSD sync
# --------------------------------------------------------------------------------

def gsd_synced_result(config_dir: Path, versions_file: Path = VERSIONS_FILE) -> CheckResult:
    pin_map, missing_result = pin_map_or_missing(["GSD_CORE_VERSION"], versions_file)

    if missing_result:
        return missing_result

    pinned_version = pin_map["GSD_CORE_VERSION"]
    version_file = config_dir / "gsd-core" / "VERSION"
    hint = init_hint()

    if not version_file.is_file():
        return failed(f"{version_file} is missing; the image has '{pinned_version}'", hint)

    synced_version = version_file.read_text().strip()

    if synced_version != pinned_version:
        return failed(f"GSD in {config_dir} is '{synced_version}'; the image has '{pinned_version}'", hint)

    return passed(f"GSD {pinned_version} in {config_dir}")
