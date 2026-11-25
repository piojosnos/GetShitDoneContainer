# ------------------------------------------------------------------------------
# Checks: the checks every agent has, built from the Cursor agent description
# ------------------------------------------------------------------------------
# The image copies this file to /etc/sbx/selfcheck.d/cursor/; the runner loads it
# after the shared checks.
# ------------------------------------------------------------------------------

from agent_checks import agent_check_list
from cursor_shared import AGENT


# ------------------------------------------------------------------------------
# Check entries
# ------------------------------------------------------------------------------

CHECK_LIST = agent_check_list(AGENT)
