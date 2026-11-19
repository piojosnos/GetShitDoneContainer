# ------------------------------------------------------------------------------
# Tests of the Claude no home copy check
# ------------------------------------------------------------------------------
# Real files and links inside tmp_path.
# ------------------------------------------------------------------------------

import os

from helpers import load_agent_check

no_home_copy = load_agent_check("claude", "050_no_home_copy")


# ------------------------------------------------------------------------------
# No home copy
# ------------------------------------------------------------------------------

def test_claude_no_home_copy_passes_when_no_copy_exists_and_fails_naming_each_copy(tmp_path):
    copy_dir1 = tmp_path / "share1"
    copy_link1 = tmp_path / "bin1"

    passing_result = no_home_copy.no_home_copy_result([copy_dir1, copy_link1])
    copy_dir1.mkdir()
    os.symlink("nowhere1", copy_link1)
    failing_result = no_home_copy.no_home_copy_result([copy_dir1, copy_link1])

    assert passing_result.passed
    assert not failing_result.passed
    assert str(copy_dir1) in failing_result.detail
    assert str(copy_link1) in failing_result.detail
    assert "remove ~/.local/share/claude and ~/.local/bin/claude" in failing_result.hint
