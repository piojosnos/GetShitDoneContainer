# ------------------------------------------------------------------------------
# Check: nothing under the image's folders is writable or mounted
# ------------------------------------------------------------------------------
# The image puts this file in /usr/local/lib/sbx-selfcheck/checks/.
# ------------------------------------------------------------------------------

from pathlib import Path

from check_result import Check, CheckResult
from protected_paths import protected_paths_result

_PROTECTED_PATH_LIST = [Path("/etc/sbx"), Path("/usr/local/bin"), Path("/usr/local/lib/sbx-selfcheck")]


# ------------------------------------------------------------------------------
# Check entries
# ------------------------------------------------------------------------------

def _check_image_paths_protected() -> CheckResult:
    return protected_paths_result(_PROTECTED_PATH_LIST)


CHECK_LIST = [Check("image-paths-protected", _check_image_paths_protected)]
