# ------------------------------------------------------------------------------
# What the Cursor checks and steps share: the agent description and its constants
# ------------------------------------------------------------------------------
# The image puts this file in /usr/local/lib/sbx-selfcheck/agents/, which the
# launcher puts on the import path. The runner does not load it as a check.
# ------------------------------------------------------------------------------

from pathlib import Path

from agent_description import AgentDescription
from paths import HOME_DIR, STATE_DIR

AGENT_NAME = "cursor"
AGENT_CONFIG_DIR = STATE_DIR / "cursor"
CLI_CONFIG_FILE = AGENT_CONFIG_DIR / "cli-config.json"

# image_root_list is the directory the image installs the agent in; the ownership
# check and the protected paths check of this image walk it. The sbx commands sit
# under the base roots.
AGENT = AgentDescription(
    name=AGENT_NAME,
    config_dir=AGENT_CONFIG_DIR,
    home_link_list=[HOME_DIR / ".cursor", HOME_DIR / ".config" / "cursor"],
    login_file=AGENT_CONFIG_DIR / "auth.json",
    login_hint="log in once: run cursor-agent login in this sandbox and open the link on the host",
    environment_value_by_name_map={"CURSOR_CONFIG_DIR": str(AGENT_CONFIG_DIR)},
    image_root_list=[Path("/usr/local/lib/cursor-agent")],
    versions_field_list=[("cursor-agent", "CURSOR_AGENT_VERSION")],
    gsd_agent_option="--cursor",
)
