# --------------------------------------------------------------------------------
# Check: the image holds no copy of the best-practices repo
# --------------------------------------------------------------------------------
# The image puts this file in /usr/local/lib/sbx-selfcheck/checks/.
# --------------------------------------------------------------------------------

from pathlib import Path

from check_result import Check, CheckResult, failed, passed
from hints import rebuild_hint
from paths import path_is_present

_BEST_PRACTICES_COPY_PATH = Path("/opt/sbx/best-practices")


# --------------------------------------------------------------------------------
# No best-practices copy
# --------------------------------------------------------------------------------

def no_best_practices_copy_result(best_practices_copy_path: Path = _BEST_PRACTICES_COPY_PATH) -> CheckResult:
    if path_is_present(best_practices_copy_path):
        return failed(f"the image holds a best-practices copy at {best_practices_copy_path}", rebuild_hint())

    return passed(f"no best-practices copy at {best_practices_copy_path}")


# --------------------------------------------------------------------------------
# Check entries
# --------------------------------------------------------------------------------

def _check_no_best_practices_copy() -> CheckResult:
    return no_best_practices_copy_result()


CHECK_LIST = [Check("no-best-practices-copy", _check_no_best_practices_copy)]
