# ------------------------------------------------------------------------------
# The checks of the Claude image
# ------------------------------------------------------------------------------
# The image copies this file to /etc/sbx/selfcheck.d/claude.py; the runner loads
# it after the shared checks.
# ------------------------------------------------------------------------------

import json
from pathlib import Path

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
    path_is_present,
    pin_map_or_missing,
    problem_list_result,
    protected_paths_result,
    rebuild_hint,
    root_owned_result,
    tool_result,
)


# ------------------------------------------------------------------------------
# Constants
# ------------------------------------------------------------------------------

_CLAUDE_CONFIG_DIR = STATE_DIR / "claude"
_CLAUDE_HOME_LINK = HOME_DIR / ".claude"
_CLAUDE_HOME_COPY_PATH_LIST = [
    HOME_DIR / ".local" / "share" / "claude",
    HOME_DIR / ".local" / "bin" / "claude",
]
_MANAGED_SETTINGS_FILE = Path("/etc/claude-code/managed-settings.json")
_CLAUDE_WRAPPER_MODE_LIST = [
    ("/usr/local/bin/sbx-claude", 0o755),
    ("/etc/sbx/start.d/05-gsd", 0o755),
    ("/etc/sbx/start.d/10-best-practices", 0o755),
    ("/etc/claude-code", 0o755),
    ("/etc/claude-code/managed-settings.json", 0o644),
    ("/etc/sbx/selfcheck.d/claude.py", 0o644),
]
_CLAUDE_PROTECTED_PATH_LIST = [Path("/etc/claude-code")]
_CLAUDE_LOGIN_HINT = "log in once: run sbx-claude in this sandbox and follow the login"


# ------------------------------------------------------------------------------
# Claude home and settings checks
# ------------------------------------------------------------------------------

def no_home_copy_result(copy_path_list: list[Path] = _CLAUDE_HOME_COPY_PATH_LIST) -> CheckResult:
    found_path_list = []

    for copy_path in copy_path_list:
        if path_is_present(copy_path):
            found_path_list.append(str(copy_path))

    if found_path_list:
        return failed(
            f"Claude left a copy of itself in the home: {', '.join(found_path_list)}",
            "Claude installed a copy of itself in the home: in this sandbox remove ~/.local/share/claude and ~/.local/bin/claude",
        )

    return passed("no copy of Claude under the home")


def _sorted_text_list(value: object) -> list[str] | None:
    if not isinstance(value, list):
        return None

    text_list = []

    for item in value:
        if not isinstance(item, str):
            return None

        text_list.append(item)

    return sorted(text_list)


def managed_settings_result(
    settings_file: Path = _MANAGED_SETTINGS_FILE,
    bundle_dir: Path = BUNDLE_DIR,
    config_dir: Path = _CLAUDE_CONFIG_DIR,
) -> CheckResult:
    try:
        settings_map = json.loads(settings_file.read_text())
    except FileNotFoundError:
        return failed(f"{settings_file} is missing", rebuild_hint())
    except (OSError, ValueError):
        return failed(f"{settings_file} is not valid JSON", rebuild_hint())

    permissions_map = {}

    if isinstance(settings_map, dict) and isinstance(settings_map.get("permissions"), dict):
        permissions_map = settings_map["permissions"]

    expected_directory_list = [str(bundle_dir)]
    expected_deny_list = sorted([f"Edit(/{config_dir}/.best-practices-skills)", f"Edit(/{config_dir}/skills/**)"])
    problem_list = []

    if _sorted_text_list(permissions_map.get("additionalDirectories")) != expected_directory_list:
        problem_list.append(
            f"additionalDirectories is {permissions_map.get('additionalDirectories')}, expected {expected_directory_list}"
        )

    if _sorted_text_list(permissions_map.get("deny")) != expected_deny_list:
        problem_list.append(f"deny is {permissions_map.get('deny')}, expected {expected_deny_list}")

    return problem_list_result(
        problem_list,
        rebuild_hint(),
        f"{settings_file} names {bundle_dir} and denies edits of the skill list and the skills",
    )


# ------------------------------------------------------------------------------
# Check entries
# ------------------------------------------------------------------------------

def _check_tool_claude() -> CheckResult:
    pin_map, missing_result = pin_map_or_missing(["CLAUDE_CODE_VERSION"])

    if missing_result:
        return missing_result

    return tool_result("claude", ["--version"], f"{pin_map['CLAUDE_CODE_VERSION']} (Claude Code)")


def _check_tool_ccusage() -> CheckResult:
    pin_map, missing_result = pin_map_or_missing(["CCUSAGE_VERSION"])

    if missing_result:
        return missing_result

    return tool_result("ccusage", ["--version"], f"ccusage {pin_map['CCUSAGE_VERSION']}")


def _check_claude_env() -> CheckResult:
    return environment_values_result({"CLAUDE_CONFIG_DIR": str(_CLAUDE_CONFIG_DIR), "DISABLE_UPDATES": "1"})


def _check_claude_home_links() -> CheckResult:
    return home_links_result([(_CLAUDE_HOME_LINK, _CLAUDE_CONFIG_DIR)])


def _check_claude_no_home_copy() -> CheckResult:
    return no_home_copy_result()


def _check_claude_credentials() -> CheckResult:
    return login_file_result(_CLAUDE_CONFIG_DIR / ".credentials.json", _CLAUDE_LOGIN_HINT)


def _check_claude_gsd_synced() -> CheckResult:
    return gsd_synced_result(_CLAUDE_CONFIG_DIR)


def _check_claude_bundle_links() -> CheckResult:
    return bundle_links_result(_CLAUDE_CONFIG_DIR, BUNDLE_DIR, True)


def _check_claude_wrappers() -> CheckResult:
    return root_owned_result(_CLAUDE_WRAPPER_MODE_LIST)


def _check_claude_managed_settings() -> CheckResult:
    return managed_settings_result()


def _check_claude_image_paths_protected() -> CheckResult:
    return protected_paths_result(_CLAUDE_PROTECTED_PATH_LIST)


def _check_claude_versions_line() -> CheckResult:
    pin_map, missing_result = pin_map_or_missing(["CLAUDE_CODE_VERSION", "CCUSAGE_VERSION"])

    if missing_result:
        return missing_result

    return versions_line_result(
        f"claude {pin_map['CLAUDE_CODE_VERSION']} | ccusage {pin_map['CCUSAGE_VERSION']} | "
    )


CHECK_LIST = [
    Check("tool-claude", _check_tool_claude),
    Check("tool-ccusage", _check_tool_ccusage),
    Check("claude-env", _check_claude_env),
    Check("claude-home-links", _check_claude_home_links),
    Check("claude-no-home-copy", _check_claude_no_home_copy),
    Check("claude-credentials", _check_claude_credentials),
    Check("claude-gsd-synced", _check_claude_gsd_synced),
    Check("claude-bundle-links", _check_claude_bundle_links),
    Check("claude-wrappers", _check_claude_wrappers),
    Check("claude-managed-settings", _check_claude_managed_settings),
    Check("claude-image-paths-protected", _check_claude_image_paths_protected),
    Check("claude-versions-line", _check_claude_versions_line),
]
