# ------------------------------------------------------------------------------
# Tests of the maven check
# ------------------------------------------------------------------------------

import paths
from helpers import load_shared_check

tool_maven = load_shared_check("200_tool_maven")


# ------------------------------------------------------------------------------
# Tool maven
# ------------------------------------------------------------------------------

def test_tool_maven_without_its_pin_reports_the_missing_pin(tmp_path):
    empty_versions = tmp_path / "empty1.env"
    empty_versions.write_text("")

    result = tool_maven.tool_maven_result(empty_versions)

    assert not result.passed
    assert result.detail == f"MAVEN_VERSION is not in {paths.VERSIONS_FILE}"
