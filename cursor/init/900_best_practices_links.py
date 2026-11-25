# ------------------------------------------------------------------------------
# Step: link the best-practices clone into the agent config directory
# ------------------------------------------------------------------------------
# The image copies this file to /etc/sbx/init.d/cursor/; it runs last, after the
# ownership step.
# ------------------------------------------------------------------------------

from agent_steps import best_practices_links_step_list
from cursor_shared import AGENT


# ------------------------------------------------------------------------------
# Step entries
# ------------------------------------------------------------------------------

STEP_LIST = best_practices_links_step_list(AGENT)
