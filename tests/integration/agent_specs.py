# ------------------------------------------------------------------------------
# The per-agent data the integration scenarios and the inventory tests share
# ------------------------------------------------------------------------------
# A scenario runs once per row, and a test of the check and step inventories
# reads its counts from here, so adding an agent means adding a row. This module
# imports no Docker code.
# ------------------------------------------------------------------------------

from dataclasses import dataclass


# ------------------------------------------------------------------------------
# AgentSpec
# ------------------------------------------------------------------------------
# session_dir is formatted with the sandbox name; None when the agent keeps no
# session files that a scenario plants.
# ------------------------------------------------------------------------------

@dataclass(frozen=True)
class AgentSpec:
    name: str
    config_dir_name: str
    login_file: str
    session_dir: str | None
    wrapper: str
    binary: str
    version_pin: str
    selfcheck_count: int
    init_step_count: int
    links_rules: bool
    links_step: str


# ------------------------------------------------------------------------------
# The rows
# ------------------------------------------------------------------------------

CLAUDE_SPEC = AgentSpec(
    name="claude",
    config_dir_name="claude",
    login_file=".credentials.json",
    session_dir="projects/-home-sandbox-workspace-{name}",
    wrapper="sbx-claude",
    binary="claude",
    version_pin="CLAUDE_CODE_VERSION",
    selfcheck_count=55,
    init_step_count=4,
    links_rules=True,
    links_step="claude-best-practices-links",
)

CURSOR_SPEC = AgentSpec(
    name="cursor",
    config_dir_name="cursor",
    login_file="auth.json",
    session_dir=None,
    wrapper="sbx-cursor",
    binary="cursor-agent",
    version_pin="CURSOR_AGENT_VERSION",
    selfcheck_count=53,
    init_step_count=5,
    links_rules=False,
    links_step="cursor-best-practices-links",
)

AGENT_SPEC_LIST = [CLAUDE_SPEC, CURSOR_SPEC]

AGENT_SPEC_BY_NAME_MAP = {}

for _agent_spec in AGENT_SPEC_LIST:
    AGENT_SPEC_BY_NAME_MAP[_agent_spec.name] = _agent_spec
