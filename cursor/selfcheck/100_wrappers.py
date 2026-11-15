# ------------------------------------------------------------------------------
# Check: the Cursor scripts and files are root-owned
# ------------------------------------------------------------------------------
# The image copies this file to /etc/sbx/selfcheck.d/cursor/; the runner loads it
# after the shared checks.
# ------------------------------------------------------------------------------

from check_result import Check, CheckResult
from root_owned import root_owned_result

_WRAPPER_MODE_LIST = [
    ("/usr/local/bin/sbx-cursor", 0o755),
    ("/etc/sbx/start.d/02-no-self-update", 0o755),
    ("/etc/sbx/start.d/05-gsd", 0o755),
    ("/etc/sbx/start.d/10-best-practices", 0o755),
    ("/etc/sbx/selfcheck.d/cursor", 0o755),
    ("/etc/sbx/selfcheck.d/cursor/010_tool_cursor_agent.py", 0o644),
    ("/etc/sbx/selfcheck.d/cursor/030_env.py", 0o644),
    ("/etc/sbx/selfcheck.d/cursor/040_home_links.py", 0o644),
    ("/etc/sbx/selfcheck.d/cursor/050_self_update_off.py", 0o644),
    ("/etc/sbx/selfcheck.d/cursor/060_credentials.py", 0o644),
    ("/etc/sbx/selfcheck.d/cursor/070_gsd_synced.py", 0o644),
    ("/etc/sbx/selfcheck.d/cursor/080_bundle_links.py", 0o644),
    ("/etc/sbx/selfcheck.d/cursor/100_wrappers.py", 0o644),
    ("/etc/sbx/selfcheck.d/cursor/110_image_paths_protected.py", 0o644),
    ("/etc/sbx/selfcheck.d/cursor/120_versions_line.py", 0o644),
]


# ------------------------------------------------------------------------------
# Check entries
# ------------------------------------------------------------------------------

def _check_cursor_wrappers() -> CheckResult:
    return root_owned_result(_WRAPPER_MODE_LIST)


CHECK_LIST = [Check("cursor-wrappers", _check_cursor_wrappers)]
