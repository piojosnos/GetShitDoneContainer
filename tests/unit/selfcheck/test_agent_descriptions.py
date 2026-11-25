# ------------------------------------------------------------------------------
# Tests of the agent descriptions
# ------------------------------------------------------------------------------
# The libraries reach sys.path through the pytest pythonpath setting in
# pyproject.toml, the way the launcher puts the image's agents directory there.
# ------------------------------------------------------------------------------

from dataclasses import replace
from pathlib import Path

import pytest

import claude_shared
import cursor_shared
import paths
from agent_description import AgentDescription

EXPECTED_CLAUDE_AGENT = AgentDescription(
    name="claude",
    config_dir=paths.STATE_DIR / "claude",
    home_link_list=[paths.HOME_DIR / ".claude"],
    login_file=paths.STATE_DIR / "claude" / ".credentials.json",
    login_hint="log in once: run sbx-claude in this sandbox and follow the login",
    environment_value_by_name_map={
        "CLAUDE_CONFIG_DIR": str(paths.STATE_DIR / "claude"),
        "DISABLE_UPDATES": "1",
    },
    image_root_list=[Path("/etc/claude-code")],
    versions_field_list=[("claude", "CLAUDE_CODE_VERSION"), ("ccusage", "CCUSAGE_VERSION")],
    gsd_agent_option="--claude",
)
EXPECTED_CURSOR_AGENT = AgentDescription(
    name="cursor",
    config_dir=paths.STATE_DIR / "cursor",
    home_link_list=[paths.HOME_DIR / ".cursor", paths.HOME_DIR / ".config" / "cursor"],
    login_file=paths.STATE_DIR / "cursor" / "auth.json",
    login_hint="log in once: run cursor-agent login in this sandbox and open the link on the host",
    environment_value_by_name_map={"CURSOR_CONFIG_DIR": str(paths.STATE_DIR / "cursor")},
    image_root_list=[Path("/usr/local/lib/cursor-agent")],
    versions_field_list=[("cursor-agent", "CURSOR_AGENT_VERSION")],
    gsd_agent_option="--cursor",
)


# ------------------------------------------------------------------------------

@pytest.mark.parametrize(
    ("shared_module", "expected_agent"),
    [
        (claude_shared, EXPECTED_CLAUDE_AGENT),
        (cursor_shared, EXPECTED_CURSOR_AGENT),
    ],
)
def test_each_agent_description_holds_the_values_its_checks_and_steps_use(shared_module, expected_agent):
    assert shared_module.AGENT == expected_agent
    assert shared_module.AGENT.name == shared_module.AGENT_NAME
    assert shared_module.AGENT.config_dir == shared_module.AGENT_CONFIG_DIR


# ------------------------------------------------------------------------------

def test_a_description_with_an_empty_list_fails_to_load():
    with pytest.raises(ValueError, match="agent claude: image_root_list is empty"):
        replace(claude_shared.AGENT, image_root_list=[])


# ------------------------------------------------------------------------------

def test_a_description_with_its_login_file_outside_its_config_dir_fails_to_load(tmp_path):
    login1 = tmp_path / "login1.json"

    with pytest.raises(ValueError, match="is not under"):
        replace(claude_shared.AGENT, login_file=login1)
