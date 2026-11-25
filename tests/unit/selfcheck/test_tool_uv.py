# --------------------------------------------------------------------------------
# Tests of the uv check
# --------------------------------------------------------------------------------

import paths
from helpers import load_shared_check

tool_uv = load_shared_check("180_tool_uv")


# --------------------------------------------------------------------------------
# Tool uv
# --------------------------------------------------------------------------------

def test_tool_uv_without_its_pin_reports_the_missing_pin(tmp_path):
    empty_versions = tmp_path / "empty1.env"
    empty_versions.write_text("")

    result = tool_uv.tool_uv_result(empty_versions)

    assert not result.passed
    assert result.detail == f"UV_IMAGE is not in {paths.VERSIONS_FILE}"
