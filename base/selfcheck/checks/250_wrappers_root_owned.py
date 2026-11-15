# ------------------------------------------------------------------------------
# Check: the image's scripts and folders are root-owned
# ------------------------------------------------------------------------------
# The image puts this file in /usr/local/lib/sbx-selfcheck/checks/.
# ------------------------------------------------------------------------------

from check_result import Check, CheckResult
from root_owned import root_owned_result

_BASE_WRAPPER_MODE_LIST = [
    ("/usr/local/bin/sbx-gh-login", 0o755),
    ("/usr/local/bin/sbx-bundle-clone", 0o755),
    ("/usr/local/bin/sbx-link-bundle", 0o755),
    ("/usr/local/bin/sbx-entrypoint", 0o755),
    ("/usr/local/bin/sbx-selfcheck", 0o755),
    ("/usr/local/bin/sbx-start-lib.sh", 0o644),
    ("/usr/local/lib/sbx-selfcheck/agent_config.py", 0o644),
    ("/usr/local/lib/sbx-selfcheck/bundle_links.py", 0o644),
    ("/usr/local/lib/sbx-selfcheck/check_result.py", 0o644),
    ("/usr/local/lib/sbx-selfcheck/commands.py", 0o644),
    ("/usr/local/lib/sbx-selfcheck/environment_values.py", 0o644),
    ("/usr/local/lib/sbx-selfcheck/hints.py", 0o644),
    ("/usr/local/lib/sbx-selfcheck/home_links.py", 0o644),
    ("/usr/local/lib/sbx-selfcheck/mounts.py", 0o644),
    ("/usr/local/lib/sbx-selfcheck/paths.py", 0o644),
    ("/usr/local/lib/sbx-selfcheck/pins.py", 0o644),
    ("/usr/local/lib/sbx-selfcheck/protected_paths.py", 0o644),
    ("/usr/local/lib/sbx-selfcheck/root_owned.py", 0o644),
    ("/usr/local/lib/sbx-selfcheck/sbx_selfcheck.py", 0o644),
    ("/usr/local/lib/sbx-selfcheck/tools.py", 0o644),
    ("/usr/local/lib/sbx-selfcheck/users.py", 0o644),
    ("/usr/local/lib/sbx-selfcheck/versions_text.py", 0o644),
    ("/usr/local/lib/sbx-selfcheck/checks/010_workspace_mount.py", 0o644),
    ("/usr/local/lib/sbx-selfcheck/checks/020_project_folder.py", 0o644),
    ("/usr/local/lib/sbx-selfcheck/checks/030_state_folders.py", 0o644),
    ("/usr/local/lib/sbx-selfcheck/checks/040_root_owned_state.py", 0o644),
    ("/usr/local/lib/sbx-selfcheck/checks/050_user.py", 0o644),
    ("/usr/local/lib/sbx-selfcheck/checks/060_home_layout.py", 0o644),
    ("/usr/local/lib/sbx-selfcheck/checks/070_home_owners.py", 0o644),
    ("/usr/local/lib/sbx-selfcheck/checks/080_architecture.py", 0o644),
    ("/usr/local/lib/sbx-selfcheck/checks/090_git_safe_directory.py", 0o644),
    ("/usr/local/lib/sbx-selfcheck/checks/100_git_identity.py", 0o644),
    ("/usr/local/lib/sbx-selfcheck/checks/110_env_state_paths.py", 0o644),
    ("/usr/local/lib/sbx-selfcheck/checks/120_env_bundle.py", 0o644),
    ("/usr/local/lib/sbx-selfcheck/checks/130_java_home.py", 0o644),
    ("/usr/local/lib/sbx-selfcheck/checks/140_tools_plain.py", 0o644),
    ("/usr/local/lib/sbx-selfcheck/checks/150_tool_gh.py", 0o644),
    ("/usr/local/lib/sbx-selfcheck/checks/160_tool_node.py", 0o644),
    ("/usr/local/lib/sbx-selfcheck/checks/170_tool_python.py", 0o644),
    ("/usr/local/lib/sbx-selfcheck/checks/180_tool_uv.py", 0o644),
    ("/usr/local/lib/sbx-selfcheck/checks/190_tool_java.py", 0o644),
    ("/usr/local/lib/sbx-selfcheck/checks/200_tool_maven.py", 0o644),
    ("/usr/local/lib/sbx-selfcheck/checks/210_tool_gsd.py", 0o644),
    ("/usr/local/lib/sbx-selfcheck/checks/220_tzdata.py", 0o644),
    ("/usr/local/lib/sbx-selfcheck/checks/230_versions_record.py", 0o644),
    ("/usr/local/lib/sbx-selfcheck/checks/240_versions_line.py", 0o644),
    ("/usr/local/lib/sbx-selfcheck/checks/250_wrappers_root_owned.py", 0o644),
    ("/usr/local/lib/sbx-selfcheck/checks/260_image_paths_protected.py", 0o644),
    ("/usr/local/lib/sbx-selfcheck/checks/270_no_bundle_copy.py", 0o644),
    ("/usr/local/lib/sbx-selfcheck/checks/280_extra_ca.py", 0o644),
    ("/etc/sbx/start.d", 0o755),
    ("/etc/sbx/selfcheck.d", 0o755),
    ("/usr/local/lib/sbx-selfcheck", 0o755),
    ("/usr/local/lib/sbx-selfcheck/checks", 0o755),
]


# ------------------------------------------------------------------------------
# Check entries
# ------------------------------------------------------------------------------

def _check_wrappers_root_owned() -> CheckResult:
    return root_owned_result(_BASE_WRAPPER_MODE_LIST)


CHECK_LIST = [Check("wrappers-root-owned", _check_wrappers_root_owned)]
