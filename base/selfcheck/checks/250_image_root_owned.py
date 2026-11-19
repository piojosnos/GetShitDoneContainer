# ------------------------------------------------------------------------------
# Check: the image's scripts and directories are root-owned
# ------------------------------------------------------------------------------
# The image puts this file in /usr/local/lib/sbx-selfcheck/checks/.
# ------------------------------------------------------------------------------

from check_result import Check, CheckResult
from image_ownership import image_ownership_result
from image_roots import base_root_list


# ------------------------------------------------------------------------------
# Check entries
# ------------------------------------------------------------------------------

def _check_image_root_owned() -> CheckResult:
    return image_ownership_result(base_root_list())


CHECK_LIST = [Check("image-root-owned", _check_image_root_owned)]
