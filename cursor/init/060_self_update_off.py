# ------------------------------------------------------------------------------
# Step: turn the Cursor CLI's self-update off
# ------------------------------------------------------------------------------
# The image is the version. The static channel makes the CLI skip its update
# check and refuse an update. The setting lives in cli-config.json under
# state/cursor, which the image cannot ship, so this step sets it. The image
# copies this file to /etc/sbx/init.d/cursor/.
# ------------------------------------------------------------------------------

import json
import os
import tempfile
from pathlib import Path

from check_result import Check, CheckResult, failed, passed
from cursor_shared import CLI_CONFIG_FILE


# ------------------------------------------------------------------------------
# The static channel
# ------------------------------------------------------------------------------

def static_channel_result(config_file: Path) -> CheckResult:
    folder_failure = _make_folder(config_file.parent)

    if folder_failure is not None:
        return folder_failure

    config_map, read_failure = _read_config_map(config_file)

    if read_failure is not None:
        return read_failure

    config_map["channel"] = "static"
    write_failure = _write_config_map(config_file, config_map)

    if write_failure is not None:
        return write_failure

    return passed(f"channel is static in {config_file}")


# ------------------------------------------------------------------------------
# Folder, reading and writing
# ------------------------------------------------------------------------------

def _make_folder(config_dir: Path) -> CheckResult | None:
    try:
        config_dir.mkdir(parents=True, exist_ok=True)
    except OSError as e:
        return failed(
            f"cannot make {config_dir}: {e.strerror}",
            "make the state folder of the sandbox writable by your Mac user, then run sbx-init again",
        )

    return None


def _fix_or_delete_failure(config_file: Path, problem_text: str) -> CheckResult:
    return failed(
        f"{config_file} {problem_text}; it was left as it was",
        f"fix or delete {config_file}, then run sbx-init again",
    )


def _read_config_map(config_file: Path) -> tuple[dict, CheckResult | None]:
    try:
        config_text = config_file.read_text() if config_file.exists() else ""
    except (OSError, UnicodeDecodeError) as e:
        return {}, _fix_or_delete_failure(config_file, f"cannot be read ({type(e).__name__})")

    if not config_text.strip():
        return {}, None

    try:
        config_map = json.loads(config_text)
    except ValueError:
        return {}, _fix_or_delete_failure(config_file, "is not valid JSON")

    if not isinstance(config_map, dict):
        return {}, _fix_or_delete_failure(config_file, "holds JSON that is not an object")

    return config_map, None


def _write_config_map(config_file: Path, config_map: dict) -> CheckResult | None:
    temp_file = None

    try:
        with tempfile.NamedTemporaryFile(
            "w", dir=config_file.parent, prefix=config_file.name + ".", suffix=".tmp", delete=False
        ) as temp_handle:
            temp_file = Path(temp_handle.name)
            temp_handle.write(json.dumps(config_map, indent=2) + "\n")

        os.replace(temp_file, config_file)
    except OSError as e:
        if temp_file is not None:
            temp_file.unlink(missing_ok=True)

        return failed(
            f"cannot write {config_file}: {e.strerror}",
            "make the state folder of the sandbox writable by your Mac user, then run sbx-init again",
        )

    return None


# ------------------------------------------------------------------------------
# Step entries
# ------------------------------------------------------------------------------

def _step_cursor_self_update_off() -> CheckResult:
    return static_channel_result(CLI_CONFIG_FILE)


STEP_LIST = [Check("cursor-self-update-off", _step_cursor_self_update_off)]
