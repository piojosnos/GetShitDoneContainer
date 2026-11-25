# ------------------------------------------------------------------------------
# The init steps every agent has, built from its agent description
# ------------------------------------------------------------------------------
# Each agent image loads them through two thin step files, so the shared ownership
# step runs between them. The image puts this file in /usr/local/lib/sbx-init/.
# ------------------------------------------------------------------------------

from pathlib import Path
from typing import Callable

from agent_description import AgentDescription
from check_result import Check, CheckResult
from gsd_sync import gsd_sync_result


# ------------------------------------------------------------------------------
# The GSD sync step
# ------------------------------------------------------------------------------

def gsd_sync_step_list(
    agent: AgentDescription,
    sync_function: Callable[[Path, str], CheckResult] = gsd_sync_result,
) -> list[Check]:
    def step_gsd_sync() -> CheckResult:
        return sync_function(agent.config_dir, agent.gsd_agent_option)

    return [Check(f"{agent.name}-gsd-sync", step_gsd_sync)]
