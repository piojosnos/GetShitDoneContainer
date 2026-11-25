# ------------------------------------------------------------------------------
# The checks every agent has, built from its agent description
# ------------------------------------------------------------------------------
# Each agent image loads them through one thin check file. The image puts this
# file in /usr/local/lib/sbx-selfcheck/.
# ------------------------------------------------------------------------------

import os
from collections.abc import Mapping
from pathlib import Path

from agent_config import gsd_synced_result, login_file_result
from agent_description import AgentDescription
from best_practices_links import best_practices_links_result
from check_result import Check, CheckResult
from environment_values import environment_values_result
from home_links import home_links_result
from image_ownership import image_ownership_result
from paths import BEST_PRACTICES_DIR
from pins import pin_map_or_missing
from protected_paths import protected_paths_result
from versions_text import versions_line_result


# ------------------------------------------------------------------------------
# The check list
# ------------------------------------------------------------------------------

def agent_check_list(
    agent: AgentDescription,
    best_practices_dir: Path = BEST_PRACTICES_DIR,
    environment_map: Mapping[str, str] = os.environ,
) -> list[Check]:
    return [
        _env_check(agent, environment_map),
        _home_links_check(agent),
        _credentials_check(agent),
        _gsd_synced_check(agent),
        _best_practices_links_check(agent, best_practices_dir),
        _image_root_owned_check(agent),
        _image_paths_protected_check(agent),
        _versions_line_check(agent),
    ]


# ------------------------------------------------------------------------------
# One check per concern
# ------------------------------------------------------------------------------

def _env_check(agent: AgentDescription, environment_map: Mapping[str, str]) -> Check:
    def check_env() -> CheckResult:
        return environment_values_result(agent.environment_value_by_name_map, environment_map)

    return Check(f"{agent.name}-env", check_env)


# ------------------------------------------------------------------------------

def _home_links_check(agent: AgentDescription) -> Check:
    def check_home_links() -> CheckResult:
        link_target_list = []

        for home_link in agent.home_link_list:
            link_target_list.append((home_link, agent.config_dir))

        return home_links_result(link_target_list)

    return Check(f"{agent.name}-home-links", check_home_links)


# ------------------------------------------------------------------------------

def _credentials_check(agent: AgentDescription) -> Check:
    def check_credentials() -> CheckResult:
        return login_file_result(agent.login_file, agent.login_hint)

    return Check(f"{agent.name}-credentials", check_credentials)


# ------------------------------------------------------------------------------

def _gsd_synced_check(agent: AgentDescription) -> Check:
    def check_gsd_synced() -> CheckResult:
        return gsd_synced_result(agent.config_dir)

    return Check(f"{agent.name}-gsd-synced", check_gsd_synced)


# ------------------------------------------------------------------------------

def _best_practices_links_check(agent: AgentDescription, best_practices_dir: Path) -> Check:
    def check_best_practices_links() -> CheckResult:
        return best_practices_links_result(agent.config_dir, best_practices_dir, agent.name)

    return Check(f"{agent.name}-best-practices-links", check_best_practices_links)


# ------------------------------------------------------------------------------

def _image_root_owned_check(agent: AgentDescription) -> Check:
    def check_image_root_owned() -> CheckResult:
        return image_ownership_result(agent.image_root_list)

    return Check(f"{agent.name}-image-root-owned", check_image_root_owned)


# ------------------------------------------------------------------------------

def _image_paths_protected_check(agent: AgentDescription) -> Check:
    def check_image_paths_protected() -> CheckResult:
        return protected_paths_result(agent.image_root_list)

    return Check(f"{agent.name}-image-paths-protected", check_image_paths_protected)


# ------------------------------------------------------------------------------

def _versions_line_check(agent: AgentDescription) -> Check:
    def check_versions_line() -> CheckResult:
        pin_name_list = []

        for _, pin_name in agent.versions_field_list:
            pin_name_list.append(pin_name)

        pin_map, missing_result = pin_map_or_missing(pin_name_list)

        if missing_result:
            return missing_result

        return versions_line_result(_versions_prefix_text(agent, pin_map))

    return Check(f"{agent.name}-versions-line", check_versions_line)


# ------------------------------------------------------------------------------

def _versions_prefix_text(agent: AgentDescription, pin_map: dict[str, str]) -> str:
    prefix_text = ""

    for label, pin_name in agent.versions_field_list:
        prefix_text += f"{label} {pin_map[pin_name]} | "

    return prefix_text
