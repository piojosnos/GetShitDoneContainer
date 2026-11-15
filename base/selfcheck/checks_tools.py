# ------------------------------------------------------------------------------
# The shared checks of what the image holds
# ------------------------------------------------------------------------------
# Tools, the versions record and line, wrappers and protected paths. The image
# puts this file in /usr/local/lib/sbx-selfcheck/.
# ------------------------------------------------------------------------------

import os
import platform
from pathlib import Path
from typing import Mapping

from selfcheck_core import (
    TOOL_VERSIONS_FILE,
    VERSIONS_FILE,
    Check,
    CheckResult,
    expected_base_versions_text,
    failed,
    first_output_line,
    image_tag,
    jdk_version,
    missing_pin_result,
    parse_versions_text,
    passed,
    path_is_present,
    pin_map_or_missing,
    problem_list_result,
    protected_paths_result,
    rebuild_hint,
    root_owned_result,
    run_command,
    tool_result,
)


# ------------------------------------------------------------------------------
# Constants
# ------------------------------------------------------------------------------

_BUNDLE_COPY_PATH = Path("/opt/sbx/best-practices")
_BASE_WRAPPER_MODE_LIST = [
    ("/usr/local/bin/sbx-gh-login", 0o755),
    ("/usr/local/bin/sbx-bundle-clone", 0o755),
    ("/usr/local/bin/sbx-link-bundle", 0o755),
    ("/usr/local/bin/sbx-entrypoint", 0o755),
    ("/usr/local/bin/sbx-selfcheck", 0o755),
    ("/usr/local/bin/sbx-start-lib.sh", 0o644),
    ("/usr/local/lib/sbx-selfcheck/agent_helpers.py", 0o644),
    ("/usr/local/lib/sbx-selfcheck/checks_certs.py", 0o644),
    ("/usr/local/lib/sbx-selfcheck/checks_env.py", 0o644),
    ("/usr/local/lib/sbx-selfcheck/checks_sandbox.py", 0o644),
    ("/usr/local/lib/sbx-selfcheck/checks_tools.py", 0o644),
    ("/usr/local/lib/sbx-selfcheck/sbx_selfcheck.py", 0o644),
    ("/usr/local/lib/sbx-selfcheck/selfcheck_core.py", 0o644),
    ("/usr/local/lib/sbx-selfcheck/shared_checks.py", 0o644),
    ("/etc/sbx/start.d", 0o755),
    ("/etc/sbx/selfcheck.d", 0o755),
    ("/usr/local/lib/sbx-selfcheck", 0o755),
]
_UTC_ZONE_FILE = Path("/usr/share/zoneinfo/UTC")
_SHARED_PIN_NAME_LIST = [
    "GH_VERSION",
    "NODE_VERSION",
    "MAVEN_VERSION",
    "GSD_CORE_VERSION",
    "TEMURIN_IMAGE",
    "UV_IMAGE",
    "BUNDLE_REPO_URL",
]
_QUIET_SHELL_FLAG_LIST = ["-c", "-lc"]
_FIRST_LINES_LIMIT = 3
_PROTECTED_PATH_LIST = [Path("/etc/sbx"), Path("/usr/local/bin"), Path("/usr/local/lib/sbx-selfcheck")]


# ------------------------------------------------------------------------------
# Image file checks
# ------------------------------------------------------------------------------

def no_bundle_copy_result(bundle_copy_path: Path = _BUNDLE_COPY_PATH) -> CheckResult:
    if path_is_present(bundle_copy_path):
        return failed(f"the image holds a bundle copy at {bundle_copy_path}", rebuild_hint())

    return passed(f"no bundle copy at {bundle_copy_path}")


# ------------------------------------------------------------------------------
# Tool and tzdata checks
# ------------------------------------------------------------------------------

def tool_gh_result(versions_file: Path = VERSIONS_FILE) -> CheckResult:
    pin_map, missing_result = pin_map_or_missing(["GH_VERSION"], versions_file)

    if missing_result:
        return missing_result

    return tool_result("gh", ["--version"], f"gh version {pin_map['GH_VERSION']}")


def tool_node_result(versions_file: Path = VERSIONS_FILE) -> CheckResult:
    pin_map, missing_result = pin_map_or_missing(["NODE_VERSION"], versions_file)

    if missing_result:
        return missing_result

    return tool_result("node", ["-v"], f"v{pin_map['NODE_VERSION']}")


def tool_uv_result(versions_file: Path = VERSIONS_FILE) -> CheckResult:
    pin_map, missing_result = pin_map_or_missing(["UV_IMAGE"], versions_file)

    if missing_result:
        return missing_result

    return tool_result("uv", ["--version"], f"uv {image_tag(pin_map['UV_IMAGE'])}")


def tool_java_result(versions_file: Path = VERSIONS_FILE) -> CheckResult:
    pin_map, missing_result = pin_map_or_missing(["TEMURIN_IMAGE"], versions_file)

    if missing_result:
        return missing_result

    return tool_result(
        "java", ["-version"], f'openjdk version "{jdk_version(pin_map["TEMURIN_IMAGE"])}"', required_text="Temurin"
    )


def tool_maven_result(versions_file: Path = VERSIONS_FILE) -> CheckResult:
    pin_map, missing_result = pin_map_or_missing(["MAVEN_VERSION", "TEMURIN_IMAGE"], versions_file)

    if missing_result:
        return missing_result

    return tool_result(
        "mvn",
        ["-v"],
        f"Apache Maven {pin_map['MAVEN_VERSION']}",
        required_text=f"Java version: {jdk_version(pin_map['TEMURIN_IMAGE'])},",
    )


def tool_gsd_result(versions_file: Path = VERSIONS_FILE) -> CheckResult:
    pin_map, missing_result = pin_map_or_missing(["GSD_CORE_VERSION"], versions_file)

    if missing_result:
        return missing_result

    return tool_result(
        "gsd-tools",
        ["runtime-identity", "--raw"],
        '{"packageName":"@opengsd/gsd-core","version":"' + pin_map["GSD_CORE_VERSION"] + '"}',
    )


def _tool_python_result() -> CheckResult:
    return tool_result("python3", ["--version"], f"Python {platform.python_version()}")


def _plain_tool_check(command_name: str) -> Check:
    def run_tool_check() -> CheckResult:
        return tool_result(command_name)

    return Check("tool-" + command_name, run_tool_check)


def tzdata_result(utc_zone_file: Path = _UTC_ZONE_FILE) -> CheckResult:
    if not utc_zone_file.exists():
        return failed(f"{utc_zone_file} is missing; tzdata is not installed", rebuild_hint())

    return passed(f"{utc_zone_file} exists")


# ------------------------------------------------------------------------------
# Versions record and line checks
# ------------------------------------------------------------------------------

def _first_lines(text: str) -> str:
    line_list = []

    for line in text.splitlines():
        if line.strip():
            line_list.append(line.strip())

    return " / ".join(line_list[:_FIRST_LINES_LIMIT])


def versions_record_result(versions_file: Path = VERSIONS_FILE) -> CheckResult:
    if not versions_file.is_file():
        return failed(f"{versions_file} is missing", rebuild_hint())

    value_by_name_map = parse_versions_text(versions_file.read_text())
    missing_list = []

    for name in _SHARED_PIN_NAME_LIST:
        if not value_by_name_map.get(name):
            missing_list.append(name)

    if missing_list:
        return failed(f"{', '.join(missing_list)} missing or empty in {versions_file}", rebuild_hint())

    return passed(f"{len(value_by_name_map)} pins in {versions_file}")


def versions_line_file_result(
    versions_line_file: Path = TOOL_VERSIONS_FILE,
    versions_file: Path = VERSIONS_FILE,
) -> CheckResult:
    try:
        base_text = expected_base_versions_text(versions_file)
    except KeyError as e:
        return missing_pin_result(e.args[0])

    if not versions_line_file.is_file():
        return failed(f"{versions_line_file} is missing", rebuild_hint())

    actual_text = versions_line_file.read_text()
    one_line_text = actual_text.rstrip("\n")

    if actual_text.endswith("\n") and "\n" not in one_line_text and (
        one_line_text == base_text or one_line_text.endswith(" | " + base_text)
    ):
        return passed(f"the line ends with {base_text}")

    return failed(
        f"{versions_line_file} holds '{_first_lines(actual_text)}'; expected one line ending with '{base_text}'",
        rebuild_hint(),
    )


def _history_free_environment(environment_map: Mapping[str, str] = os.environ) -> dict[str, str]:
    history_free_environment_map = dict(environment_map)
    history_free_environment_map["HISTFILE"] = "/dev/null"

    return history_free_environment_map


def interactive_versions_line_result(
    versions_line_file: Path = TOOL_VERSIONS_FILE,
    environment_map: Mapping[str, str] = os.environ,
) -> CheckResult:
    if not versions_line_file.is_file():
        return failed(f"{versions_line_file} is missing", rebuild_hint())

    expected_text = versions_line_file.read_text()
    completed = run_command(["bash", "-i"], _history_free_environment(environment_map))

    if completed.stdout != expected_text:
        return failed(
            f"an interactive shell printed '{_first_lines(completed.stdout)}'; expected the versions line once",
            rebuild_hint(),
        )

    return passed(f"an interactive shell prints {versions_line_file} once")


def quiet_shells_result(environment_map: Mapping[str, str] = os.environ) -> CheckResult:
    problem_list = []

    for flag in _QUIET_SHELL_FLAG_LIST:
        completed = run_command(["bash", flag, "true"], environment_map)

        if completed.stdout or completed.stderr:
            problem_list.append(f"bash {flag} true printed '{first_output_line(completed)}'")

    return problem_list_result(problem_list, rebuild_hint(), "bash -c true and bash -lc true print nothing")


# ------------------------------------------------------------------------------
# Check entries
# ------------------------------------------------------------------------------

def _check_tool_gh() -> CheckResult:
    return tool_gh_result()


def _check_tool_node() -> CheckResult:
    return tool_node_result()


def _check_tool_python() -> CheckResult:
    return _tool_python_result()


def _check_tool_uv() -> CheckResult:
    return tool_uv_result()


def _check_tool_java() -> CheckResult:
    return tool_java_result()


def _check_tool_maven() -> CheckResult:
    return tool_maven_result()


def _check_tool_gsd() -> CheckResult:
    return tool_gsd_result()


def _check_tzdata() -> CheckResult:
    return tzdata_result()


def _check_versions_record() -> CheckResult:
    return versions_record_result()


def _check_versions_line_file() -> CheckResult:
    return versions_line_file_result()


def _check_versions_line_interactive() -> CheckResult:
    return interactive_versions_line_result()


def _check_versions_line_quiet() -> CheckResult:
    return quiet_shells_result()


def _check_wrappers_root_owned() -> CheckResult:
    return root_owned_result(_BASE_WRAPPER_MODE_LIST)


def _check_image_paths_protected() -> CheckResult:
    return protected_paths_result(_PROTECTED_PATH_LIST)


def _check_no_bundle_copy() -> CheckResult:
    return no_bundle_copy_result()


TOOL_CHECK_LIST = [
    _plain_tool_check("git"),
    _plain_tool_check("bash"),
    Check("tool-gh", _check_tool_gh),
    Check("tool-node", _check_tool_node),
    Check("tool-python", _check_tool_python),
    Check("tool-uv", _check_tool_uv),
    Check("tool-java", _check_tool_java),
    _plain_tool_check("keytool"),
    Check("tool-maven", _check_tool_maven),
    Check("tool-gsd", _check_tool_gsd),
    _plain_tool_check("jq"),
    _plain_tool_check("rg"),
    _plain_tool_check("unzip"),
    _plain_tool_check("zip"),
    _plain_tool_check("ssh"),
    _plain_tool_check("make"),
    _plain_tool_check("gcc"),
    Check("tzdata", _check_tzdata),
    Check("versions-record", _check_versions_record),
    Check("versions-line-file", _check_versions_line_file),
    Check("versions-line-interactive", _check_versions_line_interactive),
    Check("versions-line-quiet", _check_versions_line_quiet),
    Check("wrappers-root-owned", _check_wrappers_root_owned),
    Check("image-paths-protected", _check_image_paths_protected),
    Check("no-bundle-copy", _check_no_bundle_copy),
]
