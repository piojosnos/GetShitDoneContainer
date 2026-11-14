# The checks every sandbox image shares. The image puts this file in
# /usr/local/lib/sbx-selfcheck/ and the launcher runs CHECK_LIST first.

import hashlib
import os
import platform
import pwd
import ssl
import tempfile
from pathlib import Path
from typing import Mapping

from sbx_selfcheck import (
    BUNDLE_DIR,
    ELF_MACHINE_BY_UNAME_MAP,
    MOUNTINFO_FILE,
    STATE_DIR,
    TOOL_VERSIONS_FILE,
    VERSIONS_FILE,
    WORKSPACE_DIR,
    Check,
    CheckResult,
    environment_values_result,
    expected_base_versions_text,
    failed,
    first_output_line,
    history_free_environment,
    image_tag,
    jdk_version,
    mac_hint,
    missing_pin_result,
    passed,
    parse_versions_text,
    pin_value,
    protected_paths_result,
    read_mount_point_set,
    rebuild_hint,
    restart_hint,
    root_owned_result,
    run_command,
    sandbox_name,
    shell_hint,
    start_hint,
    tool_result,
)

SANDBOX_UID = 1000
SANDBOX_GID = 1000
SANDBOX_USER = "sandbox"
BASE_STATE_DIR_LIST = ["shell", "gh", "git"]
SKIPPED_STATE_DIR_SET = {"cache/npm", "cache/uv", "m2"}
GSD_SYNC_FOLDER_SET = {"gsd-core", "hooks", "scripts"}
REPORTED_PATH_LIMIT = 10
STATE_WRITE_PROBE_PREFIX = ".sbx-selfcheck-"
HOME_DIR = Path("/home/sandbox")
BUNDLE_COPY_PATH = Path("/opt/sbx/best-practices")
STATE_PATH_BY_NAME_MAP = {
    "HISTFILE": "/home/sandbox/workspace/state/shell/bash_history",
    "GH_CONFIG_DIR": "/home/sandbox/workspace/state/gh",
    "GIT_CONFIG_GLOBAL": "/home/sandbox/workspace/state/git/config",
    "NPM_CONFIG_CACHE": "/home/sandbox/workspace/state/cache/npm",
    "UV_CACHE_DIR": "/home/sandbox/workspace/state/cache/uv",
}
BASE_WRAPPER_MODE_LIST = [
    ("/usr/local/bin/sbx-gh-login", 0o755),
    ("/usr/local/bin/sbx-bundle-clone", 0o755),
    ("/usr/local/bin/sbx-link-bundle", 0o755),
    ("/usr/local/bin/sbx-entrypoint", 0o755),
    ("/usr/local/bin/sbx-selfcheck", 0o755),
    ("/usr/local/bin/sbx-start-lib.sh", 0o644),
    ("/usr/local/lib/sbx-selfcheck/sbx_selfcheck.py", 0o644),
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
EXTRA_CA_DIR = Path("/usr/local/share/ca-certificates")
SYSTEM_BUNDLE_FILE = Path("/etc/ssl/certs/ca-certificates.crt")
KEYTOOL_STORE_ARGUMENT_LIST = ["-cacerts", "-storepass", "changeit"]
NO_EXTRA_CA_TEXT = "no extra root certificate installed"
PEM_BEGIN_MARKER = "-----BEGIN CERTIFICATE-----"
PEM_END_MARKER = "-----END CERTIFICATE-----"
KEYTOOL_FINGERPRINT_PREFIX = "Certificate fingerprint (SHA-256): "
KEYTOOL_ALIAS_LINE_END = "trustedCertEntry,"
PROTECTED_PATH_LIST = [Path("/etc/sbx"), Path("/usr/local/bin"), Path("/usr/local/lib/sbx-selfcheck")]


def user_name_of(uid: int) -> str:
    try:
        return pwd.getpwuid(uid).pw_name
    except KeyError:
        return "unknown"


def user_result(expected_uid: int, expected_gid: int, expected_name: str) -> CheckResult:
    actual_uid = os.getuid()
    actual_gid = os.getgid()
    actual_name = user_name_of(actual_uid)
    actual_text = f"uid {actual_uid}, gid {actual_gid}, name {actual_name}"
    expected_text = f"uid {expected_uid}, gid {expected_gid}, name {expected_name}"

    if actual_text == expected_text:
        return passed(actual_text)

    return failed(
        f"runs as uid {actual_uid}, gid {actual_gid}, name {actual_name}; expected {expected_text}",
        shell_hint(),
    )


def check_user_sandbox() -> CheckResult:
    return user_result(SANDBOX_UID, SANDBOX_GID, SANDBOX_USER)


def workspace_mount_result(
    workspace_dir: Path = WORKSPACE_DIR,
    mountinfo_file: Path = MOUNTINFO_FILE,
) -> CheckResult:
    if str(workspace_dir) not in read_mount_point_set(mountinfo_file):
        return failed(f"{workspace_dir} is not a mount point; its data would be lost on recreate", start_hint())

    if not os.access(workspace_dir, os.W_OK):
        return failed(
            f"{workspace_dir} is not writable by {user_name_of(os.getuid())}",
            mac_hint(
                "make the project folder writable by your Mac user, then restart the sandbox",
                f"sbx-stop {sandbox_name()}, then sbx-start {sandbox_name()}",
            ),
        )

    return passed(f"{workspace_dir} is a writable mount point")


def project_folder_result(workspace_dir: Path, project_name: str) -> CheckResult:
    start_text = mac_hint("start the sandbox with sbx-start, which checks the project folder", f"sbx-start {sandbox_name()}")

    if not project_name:
        return failed("SBX_NAME is not set", start_text)

    project_dir = workspace_dir / project_name

    if not project_dir.is_dir():
        return failed(f"{project_dir} (the project folder) is missing", start_text)

    return passed(f"{project_dir} exists")


def state_folders_result(state_dir: Path, state_dirs_text: str) -> CheckResult:
    folder_list = BASE_STATE_DIR_LIST + state_dirs_text.split()
    missing_list = []

    for folder in folder_list:
        if not (state_dir / folder).is_dir():
            missing_list.append(folder)

    if missing_list:
        return failed(
            f"missing under {state_dir}: {', '.join(missing_list)}",
            restart_hint() + "; the start makes the state folders",
        )

    return passed(f"{', '.join(folder_list)} exist under {state_dir}")


def state_writable_result(state_dir: Path) -> CheckResult:
    try:
        probe_descriptor, probe_name = tempfile.mkstemp(dir=state_dir, prefix=STATE_WRITE_PROBE_PREFIX)
    except OSError as e:
        return failed(
            f"cannot make a file in {state_dir}: {e}",
            mac_hint(
                "make the state folder of the sandbox writable by your Mac user, then restart the sandbox",
                f"sbx-stop {sandbox_name()}, then sbx-start {sandbox_name()}",
            ),
        )

    try:
        os.close(probe_descriptor)
    finally:
        os.remove(probe_name)

    return passed(f"{state_dir} is writable")


def is_tolerated_path(relative_path: Path, tolerated_folder_set: set[str]) -> bool:
    return len(relative_path.parts) >= 2 and relative_path.parts[1] in tolerated_folder_set


def scan_owned_state(
    state_dir: Path,
    owner_uid: int,
    skipped_relative_set: set[str],
    tolerated_folder_set: set[str],
) -> tuple[list[str], int]:
    reported_list = []
    tolerated_count = 0
    pending_dir_list = [state_dir]

    while pending_dir_list:
        current_dir = pending_dir_list.pop()

        with os.scandir(current_dir) as entry_iterator:
            entry_list = list(entry_iterator)

        for entry in entry_list:
            relative_path = Path(entry.path).relative_to(state_dir)

            if relative_path.as_posix() in skipped_relative_set:
                continue

            try:
                entry_stat = entry.stat(follow_symlinks=False)
            except FileNotFoundError:
                continue

            if entry_stat.st_uid == owner_uid:
                if is_tolerated_path(relative_path, tolerated_folder_set):
                    tolerated_count += 1
                else:
                    reported_list.append(relative_path.as_posix())

            if entry.is_dir(follow_symlinks=False):
                pending_dir_list.append(Path(entry.path))

    return sorted(reported_list), tolerated_count


def owned_by_uid_paths(
    state_dir: Path,
    owner_uid: int,
    skipped_relative_set: set[str],
    tolerated_folder_set: set[str],
) -> list[str]:
    return scan_owned_state(state_dir, owner_uid, skipped_relative_set, tolerated_folder_set)[0]


def root_owned_state_result(state_dir: Path, owner_uid: int) -> CheckResult:
    reported_list, tolerated_count = scan_owned_state(state_dir, owner_uid, SKIPPED_STATE_DIR_SET, GSD_SYNC_FOLDER_SET)

    if not reported_list:
        return passed(f"no root-owned path under state/ outside the GSD sync folders ({tolerated_count} tolerated)")

    return failed(
        f"{len(reported_list)} paths under state/ are owned by uid {owner_uid}: "
        + ", ".join(reported_list[:REPORTED_PATH_LIMIT]),
        "give them back to the sandbox user: in this sandbox run: chown -R sandbox:sandbox /home/sandbox/workspace/state",
    )


def home_layout_result(home_dir: Path = HOME_DIR) -> CheckResult:
    missing_list = []

    for name in [".bashrc", ".local"]:
        if not (home_dir / name).exists():
            missing_list.append(name)

    if missing_list:
        return failed(f"missing in {home_dir}: {', '.join(missing_list)}", rebuild_hint())

    return passed(f".bashrc and .local exist in {home_dir}")


def owner_name_of_path(path: Path) -> str:
    return user_name_of(path.stat().st_uid)


def owned_by_result(path_list: list[Path], owner_name: str) -> CheckResult:
    problem_list = []

    for path in path_list:
        if not path.exists():
            problem_list.append(f"{path} is missing")
            continue

        actual_owner = owner_name_of_path(path)

        if actual_owner != owner_name:
            problem_list.append(f"{path} is owned by {actual_owner}, expected {owner_name}")

    if problem_list:
        return failed("; ".join(problem_list), rebuild_hint())

    return passed(f"{len(path_list)} paths are owned by {owner_name}")


def safe_directory_result(environment: Mapping[str, str] | None = None) -> CheckResult:
    completed = run_command(["git", "config", "--system", "--get-all", "safe.directory"], environment)

    for line in completed.stdout.splitlines():
        if line.strip() == "*":
            return passed("git trusts every folder (safe.directory is *)")

    return failed("the system git config does not set safe.directory to *", rebuild_hint())


def git_identity_result(environment: Mapping[str, str] | None = None) -> CheckResult:
    empty_list = []

    for key in ["user.name", "user.email"]:
        completed = run_command(["git", "config", "--global", key], environment)

        if not completed.stdout.strip():
            empty_list.append(key)

    if empty_list:
        return failed(
            f"{' and '.join(empty_list)} not set in the global git config",
            "run sbx-gh-login in this sandbox; it asks for the name and email",
        )

    return passed("user.name and user.email are set")


def bundle_env_result(
    versions_file: Path = VERSIONS_FILE,
    environment: Mapping[str, str] | None = None,
) -> CheckResult:
    pinned_url = pin_value("BUNDLE_REPO_URL", versions_file)

    if not pinned_url:
        return missing_pin_result("BUNDLE_REPO_URL")

    return environment_values_result(
        {"BUNDLE_REPO_URL": pinned_url, "SBX_BUNDLE_DIR": str(BUNDLE_DIR)},
        environment,
    )


def no_bundle_copy_result(bundle_copy_path: Path = BUNDLE_COPY_PATH) -> CheckResult:
    if os.path.lexists(bundle_copy_path):
        return failed(f"the image holds a bundle copy at {bundle_copy_path}", rebuild_hint())

    return passed(f"no bundle copy at {bundle_copy_path}")


def architecture_result() -> CheckResult:
    machine = platform.machine()

    if machine not in ELF_MACHINE_BY_UNAME_MAP:
        return failed(f"the machine is {machine}; the images are built for aarch64 or x86_64", rebuild_hint())

    return passed(f"{machine}, ELF machine 0x{ELF_MACHINE_BY_UNAME_MAP[machine]:02X}")


def tool_gh_result(versions_file: Path = VERSIONS_FILE) -> CheckResult:
    gh_version = pin_value("GH_VERSION", versions_file)

    if not gh_version:
        return missing_pin_result("GH_VERSION")

    return tool_result("gh", ["--version"], f"gh version {gh_version}")


def tool_node_result(versions_file: Path = VERSIONS_FILE) -> CheckResult:
    node_version = pin_value("NODE_VERSION", versions_file)

    if not node_version:
        return missing_pin_result("NODE_VERSION")

    return tool_result("node", ["-v"], f"v{node_version}")


def tool_uv_result(versions_file: Path = VERSIONS_FILE) -> CheckResult:
    uv_image = pin_value("UV_IMAGE", versions_file)

    if not uv_image:
        return missing_pin_result("UV_IMAGE")

    return tool_result("uv", ["--version"], f"uv {image_tag(uv_image)}")


def tool_java_result(versions_file: Path = VERSIONS_FILE) -> CheckResult:
    temurin_image = pin_value("TEMURIN_IMAGE", versions_file)

    if not temurin_image:
        return missing_pin_result("TEMURIN_IMAGE")

    return tool_result(
        "java", ["-version"], f'openjdk version "{jdk_version(temurin_image)}"', required_text="Temurin"
    )


def tool_maven_result(versions_file: Path = VERSIONS_FILE) -> CheckResult:
    maven_version = pin_value("MAVEN_VERSION", versions_file)
    temurin_image = pin_value("TEMURIN_IMAGE", versions_file)

    if not maven_version:
        return missing_pin_result("MAVEN_VERSION")

    if not temurin_image:
        return missing_pin_result("TEMURIN_IMAGE")

    return tool_result(
        "mvn",
        ["-v"],
        f"Apache Maven {maven_version}",
        required_text=f"Java version: {jdk_version(temurin_image)},",
    )


def tool_gsd_result(versions_file: Path = VERSIONS_FILE) -> CheckResult:
    gsd_version = pin_value("GSD_CORE_VERSION", versions_file)

    if not gsd_version:
        return missing_pin_result("GSD_CORE_VERSION")

    return tool_result(
        "gsd-tools",
        ["runtime-identity", "--raw"],
        '{"packageName":"@opengsd/gsd-core","version":"' + gsd_version + '"}',
    )


def tool_python_result() -> CheckResult:
    return tool_result("python3", ["--version"], f"Python {platform.python_version()}")


def tzdata_result(utc_zone_file: Path = UTC_ZONE_FILE) -> CheckResult:
    if not utc_zone_file.exists():
        return failed(f"{utc_zone_file} is missing; tzdata is not installed", rebuild_hint())

    return passed(f"{utc_zone_file} exists")


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
    environment: Mapping[str, str] | None = None,
) -> CheckResult:
    if not versions_line_file.is_file():
        return failed(f"{versions_line_file} is missing", rebuild_hint())

    expected_text = versions_line_file.read_text()
    completed = run_command(["bash", "-i"], history_free_environment(environment))

    if completed.stdout != expected_text:
        return failed(
            f"an interactive shell printed '{first_lines(completed.stdout)}'; expected the versions line once",
            rebuild_hint(),
        )

    return passed(f"an interactive shell prints {versions_line_file} once")


def quiet_shells_result(environment: Mapping[str, str] | None = None) -> CheckResult:
    problem_list = []

    for flag in QUIET_SHELL_FLAG_LIST:
        completed = run_command(["bash", flag, "true"], environment)

        if completed.stdout or completed.stderr:
            problem_list.append(f"bash {flag} true printed '{first_output_line(completed)}'")

    if problem_list:
        return failed("; ".join(problem_list), rebuild_hint())

    return passed("bash -c true and bash -lc true print nothing")


def pem_block_list(text: str) -> list[str]:
    block_list = []

    for part in text.split(PEM_END_MARKER):
        begin_index = part.find(PEM_BEGIN_MARKER)

        if begin_index < 0:
            continue

        block_list.append(part[begin_index:] + PEM_END_MARKER)

    return block_list


def pem_fingerprint(pem_text: str) -> str:
    return hashlib.sha256(ssl.PEM_cert_to_DER_cert(pem_text)).hexdigest().upper()


def extra_cert_fingerprint_by_alias_map(extra_ca_dir: Path) -> dict[str, str]:
    fingerprint_by_alias_map = {}

    for certificate_file in sorted(extra_ca_dir.glob("sbx-extra-ca-*.crt")):
        block_list = pem_block_list(certificate_file.read_text())

        if not block_list:
            raise ValueError(f"{certificate_file} holds no certificate")

        fingerprint_by_alias_map[certificate_file.stem] = pem_fingerprint(block_list[0])

    return fingerprint_by_alias_map


def keytool_fingerprint_set(text: str) -> set[str]:
    fingerprint_set = set()

    for line in text.splitlines():
        if line.startswith(KEYTOOL_FINGERPRINT_PREFIX):
            fingerprint_set.add(line[len(KEYTOOL_FINGERPRINT_PREFIX):].strip().replace(":", "").upper())

    return fingerprint_set


def keytool_alias_set(text: str) -> set[str]:
    alias_set = set()

    for line in text.splitlines():
        stripped_line = line.strip()

        if stripped_line.endswith(KEYTOOL_ALIAS_LINE_END):
            alias_set.add(stripped_line.partition(", ")[0])

    return alias_set


def extra_certificates_text(fingerprint_by_alias_map: Mapping[str, str]) -> str:
    pair_list = []

    for alias, fingerprint in fingerprint_by_alias_map.items():
        pair_list.append(f"{alias} {fingerprint}")

    return ", ".join(pair_list)


def system_bundle_result(
    extra_ca_dir: Path = EXTRA_CA_DIR,
    bundle_file: Path = SYSTEM_BUNDLE_FILE,
) -> CheckResult:
    fingerprint_by_alias_map = extra_cert_fingerprint_by_alias_map(extra_ca_dir)

    if not fingerprint_by_alias_map:
        return passed(NO_EXTRA_CA_TEXT)

    if not bundle_file.is_file():
        return failed(f"{bundle_file} is missing", rebuild_hint())

    bundle_fingerprint_set = set()

    for block in pem_block_list(bundle_file.read_text()):
        bundle_fingerprint_set.add(pem_fingerprint(block))

    problem_list = []

    for alias, fingerprint in fingerprint_by_alias_map.items():
        if fingerprint not in bundle_fingerprint_set:
            problem_list.append(f"{alias} ({fingerprint}) is not in {bundle_file}")

    if problem_list:
        return failed("; ".join(problem_list), rebuild_hint())

    return passed(
        f"{len(fingerprint_by_alias_map)} extra root certificates in the system bundle: "
        + extra_certificates_text(fingerprint_by_alias_map)
    )


def java_cacerts_result(
    extra_ca_dir: Path = EXTRA_CA_DIR,
    keytool_argument_list: list[str] = KEYTOOL_STORE_ARGUMENT_LIST,
) -> CheckResult:
    fingerprint_by_alias_map = extra_cert_fingerprint_by_alias_map(extra_ca_dir)

    if not fingerprint_by_alias_map:
        return passed(NO_EXTRA_CA_TEXT)

    completed = run_command(["keytool", "-list"] + keytool_argument_list)

    if completed.returncode != 0:
        return failed(f"keytool -list failed: {first_output_line(completed)}", rebuild_hint())

    alias_set = keytool_alias_set(completed.stdout)
    fingerprint_set = keytool_fingerprint_set(completed.stdout)
    problem_list = []

    for alias, fingerprint in fingerprint_by_alias_map.items():
        if alias not in alias_set:
            problem_list.append(f"{alias} is not an alias in Java cacerts")
        elif fingerprint not in fingerprint_set:
            problem_list.append(f"{alias} ({fingerprint}) is not in Java cacerts")

    if problem_list:
        return failed("; ".join(problem_list), rebuild_hint())

    return passed(
        f"{len(fingerprint_by_alias_map)} extra root certificates in Java cacerts: "
        + extra_certificates_text(fingerprint_by_alias_map)
    )


def check_workspace_mount() -> CheckResult:
    return workspace_mount_result()


def check_project_folder() -> CheckResult:
    return project_folder_result(WORKSPACE_DIR, os.environ.get("SBX_NAME", ""))


def check_state_folders() -> CheckResult:
    return state_folders_result(STATE_DIR, os.environ.get("SBX_STATE_DIRS", ""))


def check_state_writable() -> CheckResult:
    return state_writable_result(STATE_DIR)


def check_no_root_owned_state() -> CheckResult:
    return root_owned_state_result(STATE_DIR, 0)


def check_home_layout() -> CheckResult:
    return home_layout_result()


def check_home_owners() -> CheckResult:
    return owned_by_result([HOME_DIR / ".local", HOME_DIR / ".local" / "state"], SANDBOX_USER)


def check_git_safe_directory() -> CheckResult:
    return safe_directory_result()


def check_git_identity() -> CheckResult:
    return git_identity_result()


def check_env_state_paths() -> CheckResult:
    return environment_values_result(STATE_PATH_BY_NAME_MAP)


def check_env_bundle() -> CheckResult:
    return bundle_env_result()


def check_java_home() -> CheckResult:
    return environment_values_result({"JAVA_HOME": "/opt/java/openjdk"})


def check_tool_git() -> CheckResult:
    return tool_result("git")


def check_tool_jq() -> CheckResult:
    return tool_result("jq")


def check_tool_rg() -> CheckResult:
    return tool_result("rg")


def check_tool_unzip() -> CheckResult:
    return tool_result("unzip")


def check_tool_zip() -> CheckResult:
    return tool_result("zip")


def check_tool_ssh() -> CheckResult:
    return tool_result("ssh")


def check_tool_make() -> CheckResult:
    return tool_result("make")


def check_tool_gcc() -> CheckResult:
    return tool_result("gcc")


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


def check_architecture() -> CheckResult:
    return architecture_result()


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


def check_extra_ca_system_bundle() -> CheckResult:
    return system_bundle_result()


def check_extra_ca_java_cacerts() -> CheckResult:
    return java_cacerts_result()


def check_wrappers_root_owned() -> CheckResult:
    return root_owned_result(BASE_WRAPPER_MODE_LIST)


def check_image_paths_protected() -> CheckResult:
    return protected_paths_result(PROTECTED_PATH_LIST)


def check_no_bundle_copy() -> CheckResult:
    return no_bundle_copy_result()


CHECK_LIST = [
    Check("workspace-mount", check_workspace_mount),
    Check("project-folder", check_project_folder),
    Check("state-folders", check_state_folders),
    Check("state-writable", check_state_writable),
    Check("no-root-owned-state", check_no_root_owned_state),
    Check("user-sandbox", check_user_sandbox),
    Check("home-layout", check_home_layout),
    Check("home-owners", check_home_owners),
    Check("architecture", check_architecture),
    Check("git-safe-directory", check_git_safe_directory),
    Check("git-identity", check_git_identity),
    Check("env-state-paths", check_env_state_paths),
    Check("env-bundle", check_env_bundle),
    Check("java-home", check_java_home),
    Check("tool-git", check_tool_git),
    Check("tool-gh", check_tool_gh),
    Check("tool-node", check_tool_node),
    Check("tool-python", check_tool_python),
    Check("tool-uv", check_tool_uv),
    Check("tool-java", check_tool_java),
    Check("tool-maven", check_tool_maven),
    Check("tool-gsd", check_tool_gsd),
    Check("tool-jq", check_tool_jq),
    Check("tool-rg", check_tool_rg),
    Check("tool-unzip", check_tool_unzip),
    Check("tool-zip", check_tool_zip),
    Check("tool-ssh", check_tool_ssh),
    Check("tool-make", check_tool_make),
    Check("tool-gcc", check_tool_gcc),
    Check("tzdata", check_tzdata),
    Check("versions-record", check_versions_record),
    Check("versions-line-file", check_versions_line_file),
    Check("versions-line-interactive", check_versions_line_interactive),
    Check("versions-line-quiet", check_versions_line_quiet),
    Check("wrappers-root-owned", check_wrappers_root_owned),
    Check("image-paths-protected", check_image_paths_protected),
    Check("no-bundle-copy", check_no_bundle_copy),
    Check("extra-ca-system-bundle", check_extra_ca_system_bundle),
    Check("extra-ca-java-cacerts", check_extra_ca_java_cacerts),
]
