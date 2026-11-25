# --------------------------------------------------------------------------------
# Check: tzdata is installed
# --------------------------------------------------------------------------------
# The image puts this file in /usr/local/lib/sbx-selfcheck/checks/.
# --------------------------------------------------------------------------------

from pathlib import Path

from check_result import Check, CheckResult, failed, passed
from hints import rebuild_hint

_UTC_ZONE_FILE = Path("/usr/share/zoneinfo/UTC")


# --------------------------------------------------------------------------------
# Tzdata
# --------------------------------------------------------------------------------

def tzdata_result(utc_zone_file: Path = _UTC_ZONE_FILE) -> CheckResult:
    if not utc_zone_file.exists():
        return failed(f"{utc_zone_file} is missing; tzdata is not installed", rebuild_hint())

    return passed(f"{utc_zone_file} exists")


# --------------------------------------------------------------------------------
# Check entries
# --------------------------------------------------------------------------------

def _check_tzdata() -> CheckResult:
    return tzdata_result()


CHECK_LIST = [Check("tzdata", _check_tzdata)]
