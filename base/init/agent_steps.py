# ------------------------------------------------------------------------------
# The init steps every agent has, built from its agent description
# ------------------------------------------------------------------------------
# Each agent image loads them through two thin step files, so the shared ownership
# step runs between them. The image puts this file in /usr/local/lib/sbx-init/.
# ------------------------------------------------------------------------------

from pathlib import Path
from typing import Callable

from agent_description import AgentDescription
from best_practices_linker import link_best_practices
from check_result import Check, CheckResult
from gsd_sync import gsd_sync_result
from paths import BEST_PRACTICES_DIR


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


# ------------------------------------------------------------------------------
# The best-practices links step
# ------------------------------------------------------------------------------

def best_practices_links_step_list(agent: AgentDescription) -> list[Check]:
    def step_best_practices_links() -> CheckResult:
        return link_best_practices(agent.config_dir, BEST_PRACTICES_DIR, agent.name)

    return [Check(f"{agent.name}-best-practices-links", step_best_practices_links)]
