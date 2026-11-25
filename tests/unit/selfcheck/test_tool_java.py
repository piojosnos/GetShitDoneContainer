# --------------------------------------------------------------------------------
# Tests of the java check
# --------------------------------------------------------------------------------

import paths
from helpers import load_shared_check

tool_java = load_shared_check("190_tool_java")


# --------------------------------------------------------------------------------
# Tool java
# --------------------------------------------------------------------------------

def test_tool_java_without_its_pin_reports_the_missing_pin(tmp_path):
    empty_versions = tmp_path / "empty1.env"
    empty_versions.write_text("")

    result = tool_java.tool_java_result(empty_versions)

    assert not result.passed
    assert result.detail == f"TEMURIN_IMAGE is not in {paths.VERSIONS_FILE}"
