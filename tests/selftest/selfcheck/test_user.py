# ------------------------------------------------------------------------------
# Tests of the sandbox user check
# ------------------------------------------------------------------------------

import os

import hints
from helpers import load_shared_check

user = load_shared_check("050_user")


# ------------------------------------------------------------------------------
# Sandbox user
# ------------------------------------------------------------------------------

def test_user_passes_for_the_running_user_and_prints_its_ids():
    name = user.user_name_of(os.getuid())

    result = user._user_result(os.getuid(), os.getgid(), name)

    assert result.passed
    assert result.detail == f"uid {os.getuid()}, gid {os.getgid()}, name {name}"


def test_user_fails_with_the_shell_hint_for_another_uid():
    result = user._user_result(os.getuid() + 1, os.getgid(), user.user_name_of(os.getuid()))

    assert not result.passed
    assert f"runs as uid {os.getuid()}" in result.detail
    assert result.hint == hints.shell_hint()
