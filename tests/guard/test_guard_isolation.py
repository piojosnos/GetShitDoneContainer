# ------------------------------------------------------------------------------
# Guard rules on isolation: no socket or privilege, data kept, test images
# ------------------------------------------------------------------------------
# Mounts and effective privileges of a running sandbox are checked on the host
# by the isolation scenario, which reads the running container.
# ------------------------------------------------------------------------------

import re

from guard_helpers import (
    REPO_DIR,
    compose_file,
    dockerfile_list,
    host_python_list,
    launcher_list,
    line_list,
    nowhere_matches,
    relative_name,
)

_FIELD_PATTERN = (
    r"^\s*(privileged|cap_add|devices|device_cgroup_rules|pid|ipc|uts|userns_mode"
    r"|network_mode|cgroup_parent|group_add|sysctls)\s*:"
)
_UNCONFINED_PATTERN = r"(seccomp|apparmor)[=:]\s*unconfined"
_PYTHON_DELETE_PATTERN = (
    r"rmtree|os\.remove|\.unlink\(|os\.unlink|\.rmdir\(|os\.rmdir"
    r"|[\"'](rm|rmi|down|prune|kill)[\"']|--volumes"
)
_SHELL_DELETE_PATTERN = r"\b(rm|rmdir|prune|kill|down)\b|--volumes"
_SKILL_DENY_ENTRY = "Edit(//home/sandbox/workspace/state/claude/skills/**)"


# ------------------------------------------------------------------------------
# Rule no_docker_socket_or_privileges: no Docker socket, no sudo, no extra privilege
# ------------------------------------------------------------------------------
# Compose refuses privileged, cap_add, devices, host namespaces, group_add and
# unconfined profiles; the isolation scenario reads the running container.
# ------------------------------------------------------------------------------

def test_no_docker_socket_or_privileges():
    compose_hit_list = nowhere_matches(
        rf"docker\.sock|{_FIELD_PATTERN}|{_UNCONFINED_PATTERN}", [compose_file()]
    )
    sudo_hit_list = nowhere_matches(r"\bsudo\b", dockerfile_list())

    assert not compose_hit_list + sudo_hit_list, "\n".join(compose_hit_list + sudo_hit_list)


# ------------------------------------------------------------------------------
# Rule host_scripts_keep_sandbox_data: only the rm command takes a sandbox down
# ------------------------------------------------------------------------------
# Every host module other than rm.py and clean.py is free of file deletion and of
# the Docker verbs rm, rmi, down, prune and kill and of --volumes; every launcher
# in bin/ other than sbx-rm is free of the same words, so no other command deletes
# data or takes a sandbox down. What sbx-rm itself removes is proven on real
# Docker by the rm scenario.
# ------------------------------------------------------------------------------

def test_host_scripts_keep_sandbox_data():
    rm_module = REPO_DIR / "sbx" / "rm.py"

    assert rm_module.is_file(), "sbx/rm.py is missing"

    other_python_list = []

    for path in host_python_list():
        if path.name not in ("rm.py", "clean.py"):
            other_python_list.append(path)

    other_launcher_list = []

    for path in launcher_list():
        if path.parent == REPO_DIR / "bin" and path.name != "sbx-rm":
            other_launcher_list.append(path)

    hit_list = nowhere_matches(_PYTHON_DELETE_PATTERN, other_python_list)
    hit_list += nowhere_matches(_SHELL_DELETE_PATTERN, other_launcher_list)

    assert not hit_list, "\n".join(hit_list)


# ------------------------------------------------------------------------------
# Rule managed_settings_deny_skill_edits: managed settings deny Edit on synced skills
# ------------------------------------------------------------------------------
# sbx-selfcheck reads the same entry in the image.
# ------------------------------------------------------------------------------

def test_managed_settings_deny_skill_edits():
    settings_text = (REPO_DIR / "claude" / "managed-settings.json").read_text(encoding="utf-8")

    assert f'"{_SKILL_DENY_ENTRY}"' in settings_text, (
        f"claude/managed-settings.json has no deny entry {_SKILL_DENY_ENTRY}"
    )


# ------------------------------------------------------------------------------
# Rule host_tests_never_name_the_local_tag: a test run never uses your sandbox images
# ------------------------------------------------------------------------------
# The host run and the integration scenarios take their images from SBX_IMAGE_TAG,
# which they always set to test. A local tag named in one of them, even in a
# comment, is the first step to a run that replaces the images your sandboxes use.
# ------------------------------------------------------------------------------

def test_host_tests_never_name_the_local_tag():
    candidate_list = [
        REPO_DIR / "host-test.sh",
        REPO_DIR / "sbx" / "host_test.py",
        REPO_DIR / "sbx" / "hosttest_names.py",
    ]
    candidate_list += sorted((REPO_DIR / "tests" / "integration").glob("**/*.py"))

    file_list = []

    for path in candidate_list:
        if path.is_file():
            file_list.append(path)

    hit_list = nowhere_matches(r":local\b", file_list)

    assert not hit_list, "\n".join(hit_list)


# ------------------------------------------------------------------------------
# Rule owner_fix_hint_matches_container_name: the host fix names the compose container
# ------------------------------------------------------------------------------
# The fix, shared by sbx-selfcheck and sbx-init, runs a throwaway root container
# with --volumes-from sbx-NAME. If the container_name in compose.yml changes, the
# printed command would name a container that does not exist.
# ------------------------------------------------------------------------------

def test_owner_fix_hint_matches_container_name():
    hint_file = REPO_DIR / "base" / "selfcheck" / "root_owned_scan.py"
    name_prefix = None

    for line in line_list(compose_file()):
        found = re.match(r' *container_name: "(.*)\$\{SBX_NAME\}".*$', line)

        if found:
            name_prefix = found.group(1)
            break

    assert name_prefix, 'compose.yml has no container_name of the form "PREFIX${SBX_NAME}"'

    expected = "--volumes-from " + name_prefix + "{sandbox_name("

    assert expected in hint_file.read_text(encoding="utf-8"), (
        f"{relative_name(hint_file)} does not name the container as {expected}...)}}, "
        "the container_name of compose.yml"
    )
