# ------------------------------------------------------------------------------
# Check: the image holds no copy of the best-practices bundle
# ------------------------------------------------------------------------------
# The image puts this file in /usr/local/lib/sbx-selfcheck/checks/.
# ------------------------------------------------------------------------------

from pathlib import Path

from check_result import Check, CheckResult, failed, passed
from hints import rebuild_hint
from paths import path_is_present

_BUNDLE_COPY_PATH = Path("/opt/sbx/best-practices")


# ------------------------------------------------------------------------------
# No bundle copy
# ------------------------------------------------------------------------------

def no_bundle_copy_result(bundle_copy_path: Path = _BUNDLE_COPY_PATH) -> CheckResult:
    if path_is_present(bundle_copy_path):
        return failed(f"the image holds a bundle copy at {bundle_copy_path}", rebuild_hint())

    return passed(f"no bundle copy at {bundle_copy_path}")


# ------------------------------------------------------------------------------
# Check entries
# ------------------------------------------------------------------------------

def _check_no_bundle_copy() -> CheckResult:
    return no_bundle_copy_result()


CHECK_LIST = [Check("no-bundle-copy", _check_no_bundle_copy)]
