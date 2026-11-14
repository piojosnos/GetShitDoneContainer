# The checks every sandbox image shares. The image puts this file in
# /usr/local/lib/sbx-selfcheck/ and the launcher runs CHECK_LIST first.

import os
import pwd

from sbx_selfcheck import Check, CheckResult, failed, passed, shell_hint

SANDBOX_UID = 1000
SANDBOX_GID = 1000
SANDBOX_USER = "sandbox"


def user_name_of(uid: int) -> str:
    try:
        return pwd.getpwuid(uid).pw_name
    except KeyError:
        return "unknown"


def user_result(expected_uid: int, expected_gid: int, expected_name: str) -> CheckResult:
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


def check_user_sandbox() -> CheckResult:
    return user_result(SANDBOX_UID, SANDBOX_GID, SANDBOX_USER)


CHECK_LIST = [
    Check("user-sandbox", check_user_sandbox),
]
