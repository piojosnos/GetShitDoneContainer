# ------------------------------------------------------------------------------
# The description of an agent: the values its checks and steps differ by
# ------------------------------------------------------------------------------
# The image puts this file in /usr/local/lib/sbx-selfcheck/, so both launchers can
# import it. It holds data only and imports nothing but the standard library, so
# an agent library can import it with no cycle.
# ------------------------------------------------------------------------------

from dataclasses import dataclass
from pathlib import Path


# ------------------------------------------------------------------------------
# What differs between the agents
# ------------------------------------------------------------------------------

@dataclass(frozen=True)
class AgentDescription:
    name: str
    config_dir: Path
    home_link_list: list[Path]
    login_file: Path
    login_hint: str
    environment_value_by_name_map: dict[str, str]
    image_root_list: list[Path]
    versions_field_list: list[tuple[str, str]]
    gsd_agent_option: str
