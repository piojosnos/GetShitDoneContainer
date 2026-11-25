# --------------------------------------------------------------------------------
# Tests of the python3 check
# --------------------------------------------------------------------------------

import os
import shutil

from helpers import load_shared_check

tool_python = load_shared_check("170_tool_python")


# --------------------------------------------------------------------------------
# Tool python
# --------------------------------------------------------------------------------

def test_tool_python_passes_for_the_python_that_runs_the_checks():
    result = tool_python.CHECK_LIST[0].function()

    assert result.passed
    assert os.path.realpath(shutil.which("python3")) in result.detail
