# --------------------------------------------------------------------------------
# Check: sbx-init passed in this container
# --------------------------------------------------------------------------------
# The image puts this file in /usr/local/lib/sbx-selfcheck/checks/. It reports
# the marker; it never runs sbx-init.
# --------------------------------------------------------------------------------

from pathlib import Path

from check_result import Check, CheckResult, failed, passed
from hints import init_hint
from paths import INIT_MARKER_FILE


# --------------------------------------------------------------------------------
# Init marker
# --------------------------------------------------------------------------------

def init_marker_result(marker_file: Path) -> CheckResult:
    if marker_file.is_file():
        return passed(f"{marker_file} is there: sbx-init passed in this container")

    return failed(
        f"{marker_file} is missing: sbx-init has not passed since this container was made",
        init_hint(),
    )


# --------------------------------------------------------------------------------
# Check entries
# --------------------------------------------------------------------------------

def _check_init_marker() -> CheckResult:
    return init_marker_result(INIT_MARKER_FILE)


CHECK_LIST = [Check("init-marker", _check_init_marker)]
