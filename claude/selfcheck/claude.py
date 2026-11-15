# The checks of the Claude image. The image copies this file to
# /etc/sbx/selfcheck.d/claude.py and the runner loads it after the shared checks.

import json
import os
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
    Check,
    CheckResult,
    environment_values_result,
    failed,
    missing_pin_result,
    passed,
    pin_value,
    protected_paths_result,
    rebuild_hint,
    root_owned_result,
    tool_result,
)

CLAUDE_CONFIG_DIR = Path("/home/sandbox/workspace/state/claude")
CLAUDE_HOME_LINK = Path("/home/sandbox/.claude")
CLAUDE_HOME_COPY_PATH_LIST = [
    Path("/home/sandbox/.local/share/claude"),
    Path("/home/sandbox/.local/bin/claude"),
]
MANAGED_SETTINGS_FILE = Path("/etc/claude-code/managed-settings.json")
CLAUDE_WRAPPER_MODE_LIST = [
    ("/usr/local/bin/sbx-claude", 0o755),
    ("/etc/sbx/start.d/05-gsd", 0o755),
    ("/etc/sbx/start.d/10-best-practices", 0o755),
    ("/etc/claude-code", 0o755),
    ("/etc/claude-code/managed-settings.json", 0o644),
    ("/etc/sbx/selfcheck.d/claude.py", 0o644),
]
CLAUDE_PROTECTED_PATH_LIST = [Path("/etc/claude-code")]
CLAUDE_LOGIN_HINT = "log in once: run sbx-claude in this sandbox and follow the login"


def no_home_copy_result(copy_path_list: list[Path] = CLAUDE_HOME_COPY_PATH_LIST) -> CheckResult:
    found_path_list = []

    for copy_path in copy_path_list:
        if os.path.lexists(copy_path):
            found_path_list.append(str(copy_path))

    if found_path_list:
        return failed(
            f"Claude left a copy of itself in the home: {', '.join(found_path_list)}",
            "Claude installed a copy of itself in the home: in this sandbox remove ~/.local/share/claude and ~/.local/bin/claude",
        )

    return passed("no copy of Claude under the home")


def sorted_text_list(value: object) -> list[str] | None:
    if not isinstance(value, list):
        return None

    text_list = []

    for item in value:
        if not isinstance(item, str):
            return None

        text_list.append(item)

    return sorted(text_list)


def managed_settings_result(
    settings_file: Path = MANAGED_SETTINGS_FILE,
    bundle_dir: Path = BUNDLE_DIR,
    config_dir: Path = CLAUDE_CONFIG_DIR,
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

    if sorted_text_list(permissions_map.get("additionalDirectories")) != expected_directory_list:
        problem_list.append(
            f"additionalDirectories is {permissions_map.get('additionalDirectories')}, expected {expected_directory_list}"
        )

    if sorted_text_list(permissions_map.get("deny")) != expected_deny_list:
        problem_list.append(f"deny is {permissions_map.get('deny')}, expected {expected_deny_list}")

    if problem_list:
        return failed("; ".join(problem_list), rebuild_hint())

    return passed(f"{settings_file} names {bundle_dir} and denies edits of the skill list and the skills")


def check_tool_claude() -> CheckResult:
    pinned_version = pin_value("CLAUDE_CODE_VERSION")

    if not pinned_version:
        return missing_pin_result("CLAUDE_CODE_VERSION")

    return tool_result("claude", ["--version"], f"{pinned_version} (Claude Code)")


def check_tool_ccusage() -> CheckResult:
    pinned_version = pin_value("CCUSAGE_VERSION")

    if not pinned_version:
        return missing_pin_result("CCUSAGE_VERSION")

    return tool_result("ccusage", ["--version"], f"ccusage {pinned_version}")


def check_claude_env() -> CheckResult:
    return environment_values_result({"CLAUDE_CONFIG_DIR": str(CLAUDE_CONFIG_DIR), "DISABLE_UPDATES": "1"})


def check_claude_home_links() -> CheckResult:
    return home_links_result([(CLAUDE_HOME_LINK, CLAUDE_CONFIG_DIR)])


def check_claude_no_home_copy() -> CheckResult:
    return no_home_copy_result()


def check_claude_credentials() -> CheckResult:
    return login_file_result(CLAUDE_CONFIG_DIR / ".credentials.json", CLAUDE_LOGIN_HINT)


def check_claude_gsd_synced() -> CheckResult:
    return gsd_synced_result(CLAUDE_CONFIG_DIR)


def check_claude_bundle_links() -> CheckResult:
    return bundle_links_result(CLAUDE_CONFIG_DIR, BUNDLE_DIR, True)


def check_claude_wrappers() -> CheckResult:
    return root_owned_result(CLAUDE_WRAPPER_MODE_LIST)


def check_claude_managed_settings() -> CheckResult:
    return managed_settings_result()


def check_claude_image_paths_protected() -> CheckResult:
    return protected_paths_result(CLAUDE_PROTECTED_PATH_LIST)


def check_claude_versions_line() -> CheckResult:
    claude_version = pin_value("CLAUDE_CODE_VERSION")
    ccusage_version = pin_value("CCUSAGE_VERSION")

    if not claude_version:
        return missing_pin_result("CLAUDE_CODE_VERSION")

    if not ccusage_version:
        return missing_pin_result("CCUSAGE_VERSION")

    return versions_line_result(f"claude {claude_version} | ccusage {ccusage_version} | ")


CHECK_LIST = [
    Check("tool-claude", check_tool_claude),
    Check("tool-ccusage", check_tool_ccusage),
    Check("claude-env", check_claude_env),
    Check("claude-home-links", check_claude_home_links),
    Check("claude-no-home-copy", check_claude_no_home_copy),
    Check("claude-credentials", check_claude_credentials),
    Check("claude-gsd-synced", check_claude_gsd_synced),
    Check("claude-bundle-links", check_claude_bundle_links),
    Check("claude-wrappers", check_claude_wrappers),
    Check("claude-managed-settings", check_claude_managed_settings),
    Check("claude-image-paths-protected", check_claude_image_paths_protected),
    Check("claude-versions-line", check_claude_versions_line),
]
