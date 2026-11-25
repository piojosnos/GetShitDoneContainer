# ------------------------------------------------------------------------------
# The description of an agent: the values its checks and steps differ by
# ------------------------------------------------------------------------------
# The image puts this file in /usr/local/lib/sbx-selfcheck/, so both launchers can
# import it. It holds data only and imports nothing but the standard library, so
# an agent library can import it with no cycle.
# ------------------------------------------------------------------------------

from dataclasses import dataclass
from pathlib import Path

# An empty list would make its checks pass without looking at anything.
_REQUIRED_LIST_FIELD_LIST = [
    "home_link_list",
    "environment_value_by_name_map",
    "image_root_list",
    "versions_field_list",
]


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

    def __post_init__(self) -> None:
        for field_name in _REQUIRED_LIST_FIELD_LIST:
            if not getattr(self, field_name):
                raise ValueError(f"agent {self.name}: {field_name} is empty")

        if not self.login_file.is_relative_to(self.config_dir):
            raise ValueError(f"agent {self.name}: {self.login_file} is not under {self.config_dir}")
