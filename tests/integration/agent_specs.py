# --------------------------------------------------------------------------------
# The per-agent data the integration scenarios and the inventory tests share
# --------------------------------------------------------------------------------
# A scenario runs once per row, and a test of the check and step inventories
# reads its counts from here, so adding an agent means adding a row. This module
# imports no Docker code.
# --------------------------------------------------------------------------------

from dataclasses import dataclass


# --------------------------------------------------------------------------------
# AgentSpec
# --------------------------------------------------------------------------------
# session_dir is formatted with the sandbox name; None when the agent keeps no
# session files that a scenario plants. settings_file and instructions_file are
# the user's own files in the config directory that the GSD sync must leave as
# they are; None when the agent has no such file. rules_extension is the extension
# of the agent's generated rule files.
# --------------------------------------------------------------------------------

@dataclass(frozen=True)
class AgentSpec:
    name: str
    config_dir_name: str
    login_file: str
    session_dir: str | None
    settings_file: str | None
    instructions_file: str | None
    wrapper: str
    binary: str
    version_pin: str
    selfcheck_count: int
    init_step_count: int
    rules_extension: str
    links_step: str


# --------------------------------------------------------------------------------
# The rows
# --------------------------------------------------------------------------------

CLAUDE_SPEC = AgentSpec(
    name="claude",
    config_dir_name="claude",
    login_file=".credentials.json",
    session_dir="projects/-home-sandbox-workspace-{name}",
    settings_file="settings.json",
    instructions_file="CLAUDE.md",
    wrapper="sbx-claude",
    binary="claude",
    version_pin="CLAUDE_CODE_VERSION",
    selfcheck_count=55,
    init_step_count=4,
    rules_extension=".md",
    links_step="claude-best-practices-links",
)

CURSOR_SPEC = AgentSpec(
    name="cursor",
    config_dir_name="cursor",
    login_file="auth.json",
    session_dir=None,
    settings_file=None,
    instructions_file=None,
    wrapper="sbx-cursor",
    binary="cursor-agent",
    version_pin="CURSOR_AGENT_VERSION",
    selfcheck_count=53,
    init_step_count=5,
    rules_extension=".mdc",
    links_step="cursor-best-practices-links",
)

AGENT_SPEC_LIST = [CLAUDE_SPEC, CURSOR_SPEC]

AGENT_SPEC_BY_NAME_MAP = {}

for _agent_spec in AGENT_SPEC_LIST:
    AGENT_SPEC_BY_NAME_MAP[_agent_spec.name] = _agent_spec
