# ------------------------------------------------------------------------------
# What the Claude checks and steps share: the agent description and its constants
# ------------------------------------------------------------------------------
# The image puts this file in /usr/local/lib/sbx-selfcheck/agents/, which the
# launcher puts on the import path. The runner does not load it as a check.
# ------------------------------------------------------------------------------

from pathlib import Path

from agent_description import AgentDescription
from paths import HOME_DIR, STATE_DIR

AGENT_NAME = "claude"
AGENT_CONFIG_DIR = STATE_DIR / "claude"

# image_root_list is the directory the image installs the agent in; the ownership
# check and the protected paths check of this image walk it. The sbx commands sit
# under the base roots.
AGENT = AgentDescription(
    name=AGENT_NAME,
    config_dir=AGENT_CONFIG_DIR,
    home_link_list=[HOME_DIR / ".claude"],
    login_file=AGENT_CONFIG_DIR / ".credentials.json",
    login_hint="log in once: run sbx-claude in this sandbox and follow the login",
    environment_value_by_name_map={"CLAUDE_CONFIG_DIR": str(AGENT_CONFIG_DIR), "DISABLE_UPDATES": "1"},
    image_root_list=[Path("/etc/claude-code")],
    versions_field_list=[("claude", "CLAUDE_CODE_VERSION"), ("ccusage", "CCUSAGE_VERSION")],
    gsd_agent_option="--claude",
)
