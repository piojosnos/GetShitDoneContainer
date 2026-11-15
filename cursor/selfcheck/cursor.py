# ------------------------------------------------------------------------------
# The checks of the Cursor image
# ------------------------------------------------------------------------------
# The image copies this file to /etc/sbx/selfcheck.d/cursor.py; the runner loads
# it after the shared checks.
# ------------------------------------------------------------------------------

import json
import os
import shutil
import tempfile
from pathlib import Path
from typing import Mapping

from agent_helpers import (
    bundle_links_result,
    gsd_synced_result,
    home_links_result,
    login_file_result,
    versions_line_result,
)
from selfcheck_core import (
    BUNDLE_DIR,
    Check,
    CheckResult,
    environment_values_result,
    failed,
    missing_pin_result,
    passed,
    pin_value,
    protected_paths_result,
    restart_hint,
    root_owned_result,
    tool_result,
)


# ------------------------------------------------------------------------------
# Constants
# ------------------------------------------------------------------------------

CURSOR_CONFIG_DIR = Path("/home/sandbox/workspace/state/cursor")
CURSOR_HOME_LINK_LIST = [Path("/home/sandbox/.cursor"), Path("/home/sandbox/.config/cursor")]
CLI_CONFIG_FILE = CURSOR_CONFIG_DIR / "cli-config.json"
CURSOR_WRAPPER_MODE_LIST = [
    ("/usr/local/bin/sbx-cursor", 0o755),
    ("/etc/sbx/start.d/02-no-self-update", 0o755),
    ("/etc/sbx/start.d/05-gsd", 0o755),
    ("/etc/sbx/start.d/10-best-practices", 0o755),
    ("/etc/sbx/selfcheck.d/cursor.py", 0o644),
]
CURSOR_PROTECTED_PATH_LIST = [Path("/usr/local/lib/cursor-agent")]
CURSOR_LOGIN_HINT = "log in once: run cursor-agent login in this sandbox and open the link on the Mac"
THROWAWAY_HOME_PREFIX = "sbx-selfcheck-cursor-"


# ------------------------------------------------------------------------------
# Cursor version and update checks
# ------------------------------------------------------------------------------

def cursor_version_result(expected_version: str, environment_map: Mapping[str, str] = os.environ) -> CheckResult:
    throwaway_home = tempfile.mkdtemp(prefix=THROWAWAY_HOME_PREFIX)

    try:
        cursor_environment_map = dict(environment_map)
        cursor_environment_map.pop("CURSOR_CONFIG_DIR", None)
        cursor_environment_map["HOME"] = throwaway_home

        return tool_result("cursor-agent", ["--version"], expected_version, environment_map=cursor_environment_map)
    finally:
        shutil.rmtree(throwaway_home, ignore_errors=True)


def self_update_result(config_file: Path = CLI_CONFIG_FILE) -> CheckResult:
    hint = restart_hint() + "; the start sets the static channel"

    try:
        config_map = json.loads(config_file.read_text())
    except FileNotFoundError:
        return failed(f"{config_file} is missing", hint)
    except (OSError, ValueError):
        return failed(f"{config_file} is not valid JSON", hint)

    if not isinstance(config_map, dict) or "channel" not in config_map:
        return failed(f"{config_file} sets no channel, expected 'static'", hint)

    if config_map["channel"] != "static":
        return failed(f"the channel in {config_file} is {config_map['channel']!r}, expected 'static'", hint)

    return passed("channel is static")


# ------------------------------------------------------------------------------
# Check entries
# ------------------------------------------------------------------------------

def check_tool_cursor_agent() -> CheckResult:
    pinned_version = pin_value("CURSOR_AGENT_VERSION")

    if not pinned_version:
        return missing_pin_result("CURSOR_AGENT_VERSION")

    return cursor_version_result(pinned_version)


def check_cursor_env() -> CheckResult:
    return environment_values_result({"CURSOR_CONFIG_DIR": str(CURSOR_CONFIG_DIR)})


def check_cursor_home_links() -> CheckResult:
    link_target_list = []

    for home_link in CURSOR_HOME_LINK_LIST:
        link_target_list.append((home_link, CURSOR_CONFIG_DIR))

    return home_links_result(link_target_list)


def check_cursor_self_update_off() -> CheckResult:
    return self_update_result()


def check_cursor_credentials() -> CheckResult:
    return login_file_result(CURSOR_CONFIG_DIR / "auth.json", CURSOR_LOGIN_HINT)


def check_cursor_gsd_synced() -> CheckResult:
    return gsd_synced_result(CURSOR_CONFIG_DIR)


def check_cursor_bundle_links() -> CheckResult:
    return bundle_links_result(CURSOR_CONFIG_DIR, BUNDLE_DIR, False)


def check_cursor_wrappers() -> CheckResult:
    return root_owned_result(CURSOR_WRAPPER_MODE_LIST)


def check_cursor_image_paths_protected() -> CheckResult:
    return protected_paths_result(CURSOR_PROTECTED_PATH_LIST)


def check_cursor_versions_line() -> CheckResult:
    cursor_version = pin_value("CURSOR_AGENT_VERSION")

    if not cursor_version:
        return missing_pin_result("CURSOR_AGENT_VERSION")

    return versions_line_result(f"cursor-agent {cursor_version} | ")


CHECK_LIST = [
    Check("tool-cursor-agent", check_tool_cursor_agent),
    Check("cursor-env", check_cursor_env),
    Check("cursor-home-links", check_cursor_home_links),
    Check("cursor-self-update-off", check_cursor_self_update_off),
    Check("cursor-credentials", check_cursor_credentials),
    Check("cursor-gsd-synced", check_cursor_gsd_synced),
    Check("cursor-bundle-links", check_cursor_bundle_links),
    Check("cursor-wrappers", check_cursor_wrappers),
    Check("cursor-image-paths-protected", check_cursor_image_paths_protected),
    Check("cursor-versions-line", check_cursor_versions_line),
]
