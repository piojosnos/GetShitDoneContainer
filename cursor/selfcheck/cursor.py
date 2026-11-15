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
    HOME_DIR,
    STATE_DIR,
    Check,
    CheckResult,
    environment_values_result,
    failed,
    passed,
    pin_map_or_missing,
    protected_paths_result,
    restart_hint,
    root_owned_result,
    tool_result,
)


# ------------------------------------------------------------------------------
# Constants
# ------------------------------------------------------------------------------

_CURSOR_CONFIG_DIR = STATE_DIR / "cursor"
_CURSOR_HOME_LINK_LIST = [HOME_DIR / ".cursor", HOME_DIR / ".config" / "cursor"]
_CLI_CONFIG_FILE = _CURSOR_CONFIG_DIR / "cli-config.json"
_CURSOR_WRAPPER_MODE_LIST = [
    ("/usr/local/bin/sbx-cursor", 0o755),
    ("/etc/sbx/start.d/02-no-self-update", 0o755),
    ("/etc/sbx/start.d/05-gsd", 0o755),
    ("/etc/sbx/start.d/10-best-practices", 0o755),
    ("/etc/sbx/selfcheck.d/cursor.py", 0o644),
]
_CURSOR_PROTECTED_PATH_LIST = [Path("/usr/local/lib/cursor-agent")]
_CURSOR_LOGIN_HINT = "log in once: run cursor-agent login in this sandbox and open the link on the Mac"
_THROWAWAY_HOME_PREFIX = "sbx-selfcheck-cursor-"


# ------------------------------------------------------------------------------
# Cursor version and update checks
# ------------------------------------------------------------------------------

def cursor_version_result(expected_version: str, environment_map: Mapping[str, str] = os.environ) -> CheckResult:
    throwaway_home = tempfile.mkdtemp(prefix=_THROWAWAY_HOME_PREFIX)

    try:
        cursor_environment_map = dict(environment_map)
        cursor_environment_map.pop("CURSOR_CONFIG_DIR", None)
        cursor_environment_map["HOME"] = throwaway_home

        return tool_result("cursor-agent", ["--version"], expected_version, environment_map=cursor_environment_map)
    finally:
        shutil.rmtree(throwaway_home, ignore_errors=True)


def self_update_result(config_file: Path = _CLI_CONFIG_FILE) -> CheckResult:
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

def _check_tool_cursor_agent() -> CheckResult:
    pin_map, missing_result = pin_map_or_missing(["CURSOR_AGENT_VERSION"])

    if missing_result:
        return missing_result

    return cursor_version_result(pin_map["CURSOR_AGENT_VERSION"])


def _check_cursor_env() -> CheckResult:
    return environment_values_result({"CURSOR_CONFIG_DIR": str(_CURSOR_CONFIG_DIR)})


def _check_cursor_home_links() -> CheckResult:
    link_target_list = []

    for home_link in _CURSOR_HOME_LINK_LIST:
        link_target_list.append((home_link, _CURSOR_CONFIG_DIR))

    return home_links_result(link_target_list)


def _check_cursor_self_update_off() -> CheckResult:
    return self_update_result()


def _check_cursor_credentials() -> CheckResult:
    return login_file_result(_CURSOR_CONFIG_DIR / "auth.json", _CURSOR_LOGIN_HINT)


def _check_cursor_gsd_synced() -> CheckResult:
    return gsd_synced_result(_CURSOR_CONFIG_DIR)


def _check_cursor_bundle_links() -> CheckResult:
    return bundle_links_result(_CURSOR_CONFIG_DIR, BUNDLE_DIR, False)


def _check_cursor_wrappers() -> CheckResult:
    return root_owned_result(_CURSOR_WRAPPER_MODE_LIST)


def _check_cursor_image_paths_protected() -> CheckResult:
    return protected_paths_result(_CURSOR_PROTECTED_PATH_LIST)


def _check_cursor_versions_line() -> CheckResult:
    pin_map, missing_result = pin_map_or_missing(["CURSOR_AGENT_VERSION"])

    if missing_result:
        return missing_result

    return versions_line_result(f"cursor-agent {pin_map['CURSOR_AGENT_VERSION']} | ")


CHECK_LIST = [
    Check("tool-cursor-agent", _check_tool_cursor_agent),
    Check("cursor-env", _check_cursor_env),
    Check("cursor-home-links", _check_cursor_home_links),
    Check("cursor-self-update-off", _check_cursor_self_update_off),
    Check("cursor-credentials", _check_cursor_credentials),
    Check("cursor-gsd-synced", _check_cursor_gsd_synced),
    Check("cursor-bundle-links", _check_cursor_bundle_links),
    Check("cursor-wrappers", _check_cursor_wrappers),
    Check("cursor-image-paths-protected", _check_cursor_image_paths_protected),
    Check("cursor-versions-line", _check_cursor_versions_line),
]
