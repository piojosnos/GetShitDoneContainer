# --------------------------------------------------------------------------------
# Scenario: a running sandbox has no privilege and one bind mount
# --------------------------------------------------------------------------------
# Read from docker inspect of the real container, so a change in compose.yml or in
# Docker's defaults that widens the sandbox shows up here. A failing field is
# named with its value.
# --------------------------------------------------------------------------------

from scenario_helpers import RunSandbox, inspect_container, one_bind_mount_problem, step


# --------------------------------------------------------------------------------
# Field checks
# --------------------------------------------------------------------------------

def _is_empty(value: object) -> bool:
    return value is None or value == [] or value == ""


# --------------------------------------------------------------------------------

def _privilege_problem_list(host_config: dict) -> list[str]:
    problem_list = []
    cap_drop = host_config.get("CapDrop")
    cap_add = host_config.get("CapAdd")
    security_opt = host_config.get("SecurityOpt")
    devices = host_config.get("Devices")
    group_add = host_config.get("GroupAdd")

    if host_config.get("Privileged") is not False:
        problem_list.append(f"Privileged is {host_config.get('Privileged')!r}, expected false")

    if not cap_drop or "ALL" not in cap_drop:
        problem_list.append(f"CapDrop is {cap_drop!r}, expected it to hold ALL")

    if not _is_empty(cap_add):
        problem_list.append(f"CapAdd is {cap_add!r}, expected null or empty")

    no_new_privileges = False

    for entry in security_opt or []:
        if entry.startswith("no-new-privileges"):
            no_new_privileges = True

        if "unconfined" in entry:
            problem_list.append(f"SecurityOpt holds the unconfined profile {entry!r}")

    if not no_new_privileges:
        problem_list.append(f"SecurityOpt is {security_opt!r}, expected no-new-privileges")

    if not _is_empty(devices):
        problem_list.append(f"Devices is {devices!r}, expected null or empty")

    if not _is_empty(group_add):
        problem_list.append(f"GroupAdd is {group_add!r}, expected null or empty")

    return problem_list


# --------------------------------------------------------------------------------

def _namespace_problem_list(host_config: dict) -> list[str]:
    problem_list = []
    network_mode = host_config.get("NetworkMode") or ""
    ipc_mode = host_config.get("IpcMode")

    if network_mode == "host":
        problem_list.append("NetworkMode is 'host'")

    if network_mode.startswith("container:"):
        problem_list.append(f"NetworkMode is {network_mode!r}, which joins another container")

    for field in ["PidMode", "UTSMode", "UsernsMode"]:
        if host_config.get(field) == "host":
            problem_list.append(f"{field} is 'host'")

    if ipc_mode not in ["private", "shareable"]:
        problem_list.append(f"IpcMode is {ipc_mode!r}, expected 'private' or 'shareable'")

    return problem_list


# --------------------------------------------------------------------------------
# test_one_bind_mount_and_no_privileges
# --------------------------------------------------------------------------------
# docker inspect -> no privilege, no host namespace, one bind mount
# --------------------------------------------------------------------------------

def test_one_bind_mount_and_no_privileges(sandbox: RunSandbox):
    host_config: dict = {}

    with step("read HostConfig"):
        inspected = inspect_container(sandbox.container)

        assert inspected is not None, f"{sandbox.container} is not there"
        assert "HostConfig" in inspected, f"docker inspect of {sandbox.container} has no HostConfig"

        host_config = inspected["HostConfig"]

    with step("no privileges"):
        problem_list = _privilege_problem_list(host_config)

        assert not problem_list, "\n".join(problem_list)

    with step("no host namespaces"):
        problem_list = _namespace_problem_list(host_config)

        assert not problem_list, "\n".join(problem_list)

    with step("one bind mount"):
        problem = one_bind_mount_problem(sandbox.container, sandbox.sandbox_dir)

        assert problem is None, problem
