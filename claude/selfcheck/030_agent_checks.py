# --------------------------------------------------------------------------------
# Checks: the checks every agent has, built from the Claude agent description
# --------------------------------------------------------------------------------
# The image copies this file to /etc/sbx/selfcheck.d/claude/; the runner loads it
# after the shared checks.
# --------------------------------------------------------------------------------

from agent_checks import agent_check_list
from claude_shared import AGENT


# --------------------------------------------------------------------------------
# Check entries
# --------------------------------------------------------------------------------

CHECK_LIST = agent_check_list(AGENT)
