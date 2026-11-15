# ------------------------------------------------------------------------------
# Running commands
# ------------------------------------------------------------------------------
# One place for the flags every command the checks run gets. The image puts this
# file in /usr/local/lib/sbx-selfcheck/.
# ------------------------------------------------------------------------------

import os
import subprocess
from typing import Mapping

_COMMAND_TIMEOUT_SECONDS = 60


# ------------------------------------------------------------------------------
# Commands and command output
# ------------------------------------------------------------------------------

def run_command(
    argument_list: list[str],
    environment_map: Mapping[str, str] = os.environ,
) -> subprocess.CompletedProcess:
    return subprocess.run(
        argument_list,
        stdin=subprocess.DEVNULL,
        capture_output=True,
        text=True,
        timeout=_COMMAND_TIMEOUT_SECONDS,
        check=False,
        env=environment_map,
    )


def first_output_line(completed: subprocess.CompletedProcess) -> str:
    for output_text in [completed.stdout, completed.stderr]:
        for line in output_text.splitlines():
            if line.strip():
                return line.strip()

    return ""
