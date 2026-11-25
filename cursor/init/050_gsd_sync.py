# --------------------------------------------------------------------------------
# Step: sync the image's GSD into the agent config directory
# --------------------------------------------------------------------------------
# The image copies this file to /etc/sbx/init.d/cursor/; the runner sorts it in
# by file name.
# --------------------------------------------------------------------------------

from agent_steps import gsd_sync_step_list
from cursor_shared import AGENT


# --------------------------------------------------------------------------------
# Step entries
# --------------------------------------------------------------------------------

STEP_LIST = gsd_sync_step_list(AGENT)
