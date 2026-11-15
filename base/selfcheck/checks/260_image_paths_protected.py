# ------------------------------------------------------------------------------
# Check: nothing under the image's folders is writable or mounted
# ------------------------------------------------------------------------------
# The image puts this file in /usr/local/lib/sbx-selfcheck/checks/.
# ------------------------------------------------------------------------------

from check_result import Check, CheckResult
from image_roots import base_root_list
from protected_paths import protected_paths_result


# ------------------------------------------------------------------------------
# Check entries
# ------------------------------------------------------------------------------

def _check_image_paths_protected() -> CheckResult:
    return protected_paths_result(base_root_list())


CHECK_LIST = [Check("image-paths-protected", _check_image_paths_protected)]
