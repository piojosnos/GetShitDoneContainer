# ------------------------------------------------------------------------------
# Tests of the gh check
# ------------------------------------------------------------------------------

import paths
from helpers import load_shared_check

tool_gh = load_shared_check("150_tool_gh")


# ------------------------------------------------------------------------------
# Tool gh
# ------------------------------------------------------------------------------

def test_tool_gh_without_its_pin_reports_the_missing_pin_and_runs_nothing(tmp_path):
    empty_versions = tmp_path / "empty1.env"
    empty_versions.write_text("")

    result = tool_gh.tool_gh_result(empty_versions)

    assert not result.passed
    assert result.detail == f"GH_VERSION is not in {paths.VERSIONS_FILE}"
