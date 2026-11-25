# --------------------------------------------------------------------------------
# Check: the shell runs as the sandbox user
# --------------------------------------------------------------------------------
# The image puts this file in /usr/local/lib/sbx-selfcheck/checks/.
# --------------------------------------------------------------------------------

import os

from check_result import Check, CheckResult, failed, passed
from hints import shell_hint
from users import SANDBOX_GID, SANDBOX_UID, SANDBOX_USER, user_name_of


# --------------------------------------------------------------------------------
# Sandbox user
# --------------------------------------------------------------------------------

def _user_result(expected_uid: int, expected_gid: int, expected_name: str) -> CheckResult:
    actual_uid = os.getuid()
    actual_gid = os.getgid()
    actual_name = user_name_of(actual_uid)
    actual_text = f"uid {actual_uid}, gid {actual_gid}, name {actual_name}"
    expected_text = f"uid {expected_uid}, gid {expected_gid}, name {expected_name}"

    if actual_text == expected_text:
        return passed(actual_text)

    return failed(
        f"runs as uid {actual_uid}, gid {actual_gid}, name {actual_name}; expected {expected_text}",
        shell_hint(),
    )


# --------------------------------------------------------------------------------
# Check entries
# --------------------------------------------------------------------------------

def _check_user_sandbox() -> CheckResult:
    return _user_result(SANDBOX_UID, SANDBOX_GID, SANDBOX_USER)


CHECK_LIST = [Check("user-sandbox", _check_user_sandbox)]
