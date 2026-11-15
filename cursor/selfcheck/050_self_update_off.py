# ------------------------------------------------------------------------------
# Check: Cursor's self-update is off
# ------------------------------------------------------------------------------
# The image copies this file to /etc/sbx/selfcheck.d/cursor/; the runner loads it
# after the shared checks.
# ------------------------------------------------------------------------------

import json
from pathlib import Path

from check_result import Check, CheckResult, failed, passed
from hints import restart_hint
from paths import STATE_DIR

_CONFIG_DIR = STATE_DIR / "cursor"
_CLI_CONFIG_FILE = _CONFIG_DIR / "cli-config.json"


# ------------------------------------------------------------------------------
# Self-update
# ------------------------------------------------------------------------------

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

def _check_cursor_self_update_off() -> CheckResult:
    return self_update_result()


CHECK_LIST = [Check("cursor-self-update-off", _check_cursor_self_update_off)]
