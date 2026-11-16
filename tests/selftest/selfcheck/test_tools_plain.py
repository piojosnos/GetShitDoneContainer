# ------------------------------------------------------------------------------
# Tests of the plain tool checks
# ------------------------------------------------------------------------------
# Real tools on the PATH of the dev sandbox.
# ------------------------------------------------------------------------------

import os
import shutil

import pytest

from check_result import Check
from helpers import load_shared_check

tools_plain = load_shared_check("140_tools_plain")


# ------------------------------------------------------------------------------
# Constants and helpers
# ------------------------------------------------------------------------------

def tool_check(name: str) -> Check:
    for check in tools_plain.CHECK_LIST:
        if check.name == "tool-" + name:
            return check

    raise AssertionError(f"no tool check for {name}")


# ------------------------------------------------------------------------------
# Plain tools
# ------------------------------------------------------------------------------

def test_every_plain_tool_has_a_check_named_after_it():
    name_list = []

    for check in tools_plain.CHECK_LIST:
        name_list.append(check.name)

    assert name_list == [
        "tool-git", "tool-bash", "tool-keytool", "tool-jq", "tool-rg", "tool-unzip", "tool-zip", "tool-ssh",
        "tool-make", "tool-gcc",
    ]


def test_tool_bash_resolves_to_the_image_outside_the_home():
    result = tool_check("bash").function()
    expected_path = os.path.realpath(shutil.which("bash"))

    assert result.passed
    assert result.detail == expected_path
    assert not result.detail.startswith("/home/")


@pytest.mark.skipif(shutil.which("keytool") is None, reason="keytool is not installed here")
def test_tool_keytool_resolves_to_the_jdk_outside_the_home():
    result = tool_check("keytool").function()
    expected_path = os.path.realpath(shutil.which("keytool"))

    assert result.passed
    assert result.detail == expected_path
    assert not result.detail.startswith("/home/")
