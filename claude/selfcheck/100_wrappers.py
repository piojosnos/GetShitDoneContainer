# ------------------------------------------------------------------------------
# Check: the Claude scripts and files are root-owned
# ------------------------------------------------------------------------------
# The image copies this file to /etc/sbx/selfcheck.d/claude/; the runner loads it
# after the shared checks.
# ------------------------------------------------------------------------------

from check_result import Check, CheckResult
from root_owned import root_owned_result

_WRAPPER_MODE_LIST = [
    ("/usr/local/bin/sbx-claude", 0o755),
    ("/etc/sbx/start.d/05-gsd", 0o755),
    ("/etc/sbx/start.d/10-best-practices", 0o755),
    ("/etc/claude-code", 0o755),
    ("/etc/claude-code/managed-settings.json", 0o644),
    ("/etc/sbx/selfcheck.d/claude", 0o755),
    ("/etc/sbx/selfcheck.d/claude/010_tool_claude.py", 0o644),
    ("/etc/sbx/selfcheck.d/claude/020_tool_ccusage.py", 0o644),
    ("/etc/sbx/selfcheck.d/claude/030_env.py", 0o644),
    ("/etc/sbx/selfcheck.d/claude/040_home_links.py", 0o644),
    ("/etc/sbx/selfcheck.d/claude/050_no_home_copy.py", 0o644),
    ("/etc/sbx/selfcheck.d/claude/060_credentials.py", 0o644),
    ("/etc/sbx/selfcheck.d/claude/070_gsd_synced.py", 0o644),
    ("/etc/sbx/selfcheck.d/claude/080_bundle_links.py", 0o644),
    ("/etc/sbx/selfcheck.d/claude/090_managed_settings.py", 0o644),
    ("/etc/sbx/selfcheck.d/claude/100_wrappers.py", 0o644),
    ("/etc/sbx/selfcheck.d/claude/110_image_paths_protected.py", 0o644),
    ("/etc/sbx/selfcheck.d/claude/120_versions_line.py", 0o644),
]


# ------------------------------------------------------------------------------
# Check entries
# ------------------------------------------------------------------------------

def _check_claude_wrappers() -> CheckResult:
    return root_owned_result(_WRAPPER_MODE_LIST)


CHECK_LIST = [Check("claude-wrappers", _check_claude_wrappers)]
