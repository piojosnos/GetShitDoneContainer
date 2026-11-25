# --------------------------------------------------------------------------------
# Tests of the node check
# --------------------------------------------------------------------------------

import shutil

import pytest

from helpers import load_shared_check, write_versions

tool_node = load_shared_check("160_tool_node")


# --------------------------------------------------------------------------------
# Tool node
# --------------------------------------------------------------------------------

@pytest.mark.skipif(shutil.which("node") is None, reason="node is not installed here")
def test_tool_node_fails_when_the_pin_differs_from_the_installed_version(tmp_path):
    versions2 = write_versions(tmp_path / "versions2.env")
    versions2.write_text(versions2.read_text().replace("NODE_VERSION=24.21.0", "NODE_VERSION=0.0.1"))

    result = tool_node.tool_node_result(versions2)

    assert not result.passed
    assert "the pin is 'v0.0.1'" in result.detail
