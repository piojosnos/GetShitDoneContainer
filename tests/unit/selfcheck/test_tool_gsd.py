# --------------------------------------------------------------------------------
# Tests of the gsd check
# --------------------------------------------------------------------------------

import paths
from helpers import load_shared_check

tool_gsd = load_shared_check("210_tool_gsd")


# --------------------------------------------------------------------------------
# Tool gsd
# --------------------------------------------------------------------------------

def test_tool_gsd_without_its_pin_reports_the_missing_pin(tmp_path):
    empty_versions = tmp_path / "empty1.env"
    empty_versions.write_text("")

    result = tool_gsd.tool_gsd_result(empty_versions)

    assert not result.passed
    assert result.detail == f"GSD_CORE_VERSION is not in {paths.VERSIONS_FILE}"
