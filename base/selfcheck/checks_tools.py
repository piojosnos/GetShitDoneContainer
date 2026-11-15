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

BUNDLE_COPY_PATH = Path("/opt/sbx/best-practices")
BASE_WRAPPER_MODE_LIST = [
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
UTC_ZONE_FILE = Path("/usr/share/zoneinfo/UTC")
SHARED_PIN_NAME_LIST = [
    "GH_VERSION",
    "NODE_VERSION",
    "MAVEN_VERSION",
    "GSD_CORE_VERSION",
    "TEMURIN_IMAGE",
    "UV_IMAGE",
    "BUNDLE_REPO_URL",
]
QUIET_SHELL_FLAG_LIST = ["-c", "-lc"]
FIRST_LINES_LIMIT = 3
PROTECTED_PATH_LIST = [Path("/etc/sbx"), Path("/usr/local/bin"), Path("/usr/local/lib/sbx-selfcheck")]


# ------------------------------------------------------------------------------
# Shell environment
# ------------------------------------------------------------------------------

def history_free_environment(environment_map: Mapping[str, str] = os.environ) -> dict[str, str]:
    history_free_environment_map = dict(environment_map)
    history_free_environment_map["HISTFILE"] = "/dev/null"

    return history_free_environment_map


# ------------------------------------------------------------------------------
# Image file checks
# ------------------------------------------------------------------------------

def no_bundle_copy_result(bundle_copy_path: Path = BUNDLE_COPY_PATH) -> CheckResult:
    if os.path.lexists(bundle_copy_path):
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


def tool_python_result() -> CheckResult:
    return tool_result("python3", ["--version"], f"Python {platform.python_version()}")


def plain_tool_check(command_name: str) -> Check:
    def run_tool_check() -> CheckResult:
        return tool_result(command_name)

    return Check("tool-" + command_name, run_tool_check)


def tzdata_result(utc_zone_file: Path = UTC_ZONE_FILE) -> CheckResult:
    if not utc_zone_file.exists():
        return failed(f"{utc_zone_file} is missing; tzdata is not installed", rebuild_hint())

    return passed(f"{utc_zone_file} exists")


# ------------------------------------------------------------------------------
# Versions record and line checks
# ------------------------------------------------------------------------------

def first_lines(text: str) -> str:
    line_list = []

    for line in text.splitlines():
        if line.strip():
            line_list.append(line.strip())

    return " / ".join(line_list[:FIRST_LINES_LIMIT])


def versions_record_result(versions_file: Path = VERSIONS_FILE) -> CheckResult:
    if not versions_file.is_file():
        return failed(f"{versions_file} is missing", rebuild_hint())

    value_by_name_map = parse_versions_text(versions_file.read_text())
    missing_list = []

    for name in SHARED_PIN_NAME_LIST:
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
        f"{versions_line_file} holds '{first_lines(actual_text)}'; expected one line ending with '{base_text}'",
        rebuild_hint(),
    )


def interactive_versions_line_result(
    versions_line_file: Path = TOOL_VERSIONS_FILE,
    environment_map: Mapping[str, str] = os.environ,
) -> CheckResult:
    if not versions_line_file.is_file():
        return failed(f"{versions_line_file} is missing", rebuild_hint())

    expected_text = versions_line_file.read_text()
    completed = run_command(["bash", "-i"], history_free_environment(environment_map))

    if completed.stdout != expected_text:
        return failed(
            f"an interactive shell printed '{first_lines(completed.stdout)}'; expected the versions line once",
            rebuild_hint(),
        )

    return passed(f"an interactive shell prints {versions_line_file} once")


def quiet_shells_result(environment_map: Mapping[str, str] = os.environ) -> CheckResult:
    problem_list = []

    for flag in QUIET_SHELL_FLAG_LIST:
        completed = run_command(["bash", flag, "true"], environment_map)

        if completed.stdout or completed.stderr:
            problem_list.append(f"bash {flag} true printed '{first_output_line(completed)}'")

    return problem_list_result(problem_list, rebuild_hint(), "bash -c true and bash -lc true print nothing")


# ------------------------------------------------------------------------------
# Check entries
# ------------------------------------------------------------------------------

def check_tool_gh() -> CheckResult:
    return tool_gh_result()


def check_tool_node() -> CheckResult:
    return tool_node_result()


def check_tool_python() -> CheckResult:
    return tool_python_result()


def check_tool_uv() -> CheckResult:
    return tool_uv_result()


def check_tool_java() -> CheckResult:
    return tool_java_result()


def check_tool_maven() -> CheckResult:
    return tool_maven_result()


def check_tool_gsd() -> CheckResult:
    return tool_gsd_result()


def check_tzdata() -> CheckResult:
    return tzdata_result()


def check_versions_record() -> CheckResult:
    return versions_record_result()


def check_versions_line_file() -> CheckResult:
    return versions_line_file_result()


def check_versions_line_interactive() -> CheckResult:
    return interactive_versions_line_result()


def check_versions_line_quiet() -> CheckResult:
    return quiet_shells_result()


def check_wrappers_root_owned() -> CheckResult:
    return root_owned_result(BASE_WRAPPER_MODE_LIST)


def check_image_paths_protected() -> CheckResult:
    return protected_paths_result(PROTECTED_PATH_LIST)


def check_no_bundle_copy() -> CheckResult:
    return no_bundle_copy_result()


TOOL_CHECK_LIST = [
    plain_tool_check("git"),
    plain_tool_check("bash"),
    Check("tool-gh", check_tool_gh),
    Check("tool-node", check_tool_node),
    Check("tool-python", check_tool_python),
    Check("tool-uv", check_tool_uv),
    Check("tool-java", check_tool_java),
    plain_tool_check("keytool"),
    Check("tool-maven", check_tool_maven),
    Check("tool-gsd", check_tool_gsd),
    plain_tool_check("jq"),
    plain_tool_check("rg"),
    plain_tool_check("unzip"),
    plain_tool_check("zip"),
    plain_tool_check("ssh"),
    plain_tool_check("make"),
    plain_tool_check("gcc"),
    Check("tzdata", check_tzdata),
    Check("versions-record", check_versions_record),
    Check("versions-line-file", check_versions_line_file),
    Check("versions-line-interactive", check_versions_line_interactive),
    Check("versions-line-quiet", check_versions_line_quiet),
    Check("wrappers-root-owned", check_wrappers_root_owned),
    Check("image-paths-protected", check_image_paths_protected),
    Check("no-bundle-copy", check_no_bundle_copy),
]
