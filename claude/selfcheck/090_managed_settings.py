# ------------------------------------------------------------------------------
# Check: the managed settings name the clone and deny edits of the skills
# ------------------------------------------------------------------------------
# The image copies this file to /etc/sbx/selfcheck.d/claude/; the runner loads it
# after the shared checks.
# ------------------------------------------------------------------------------

import json
from pathlib import Path

from check_result import Check, CheckResult, failed, problem_list_result
from hints import rebuild_hint
from paths import BUNDLE_DIR, STATE_DIR

_CONFIG_DIR = STATE_DIR / "claude"
_MANAGED_SETTINGS_FILE = Path("/etc/claude-code/managed-settings.json")


# ------------------------------------------------------------------------------
# Managed settings
# ------------------------------------------------------------------------------

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
    config_dir: Path = _CONFIG_DIR,
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

def _check_claude_managed_settings() -> CheckResult:
    return managed_settings_result()


CHECK_LIST = [Check("claude-managed-settings", _check_claude_managed_settings)]
