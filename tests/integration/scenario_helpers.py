# ------------------------------------------------------------------------------
# Helpers the integration scenarios and fixtures share
# ------------------------------------------------------------------------------
# Every command a scenario runs goes through run_timeout or run_streamed: the
# command starts in its own process group, and a timeout stops the whole group,
# so no grandchild such as a docker build keeps running. Nothing here calls
# Docker when the module is imported.
# ------------------------------------------------------------------------------

import contextlib
import json
import os
import signal
import subprocess
import sys
import threading
from collections.abc import Iterator, Mapping
from dataclasses import dataclass
from pathlib import Path

from agent_specs import AgentSpec

REPO_DIR = Path(__file__).resolve().parents[2]

_GRACE_SECONDS = 5
_NOT_FOUND_EXIT_CODE = 127
_WORKSPACE_MOUNT = "/home/sandbox/workspace"
_FIX_LINE_PREFIX = "fix: "


# ------------------------------------------------------------------------------
# Data
# ------------------------------------------------------------------------------

@dataclass(frozen=True)
class CommandResult:
    returncode: int
    stdout: str
    stderr: str
    timed_out: bool


@dataclass(frozen=True)
class RunSandbox:
    name: str
    agent: AgentSpec
    sandbox_dir: Path
    project_dir: Path
    state_dir: Path
    container: str
    entry_file: Path


# ------------------------------------------------------------------------------
# step NAME: a named part of a scenario
# ------------------------------------------------------------------------------
# The exception that ends the scenario gets a note, so the pytest report names
# the failed step under the failing assertion.
# ------------------------------------------------------------------------------

@contextlib.contextmanager
def step(name: str) -> Iterator[None]:
    try:
        yield
    except Exception as e:
        e.add_note(f"STEP FAILED: {name}")

        raise


# ------------------------------------------------------------------------------
# progress TEXT: a blank line, then TEXT, flushed
# ------------------------------------------------------------------------------
# The blank line keeps the text off the end of a verbose test name line.
# ------------------------------------------------------------------------------

def progress(text: str) -> None:
    print(f"\n{text}", flush=True)


# ------------------------------------------------------------------------------
# Stopping a process group
# ------------------------------------------------------------------------------
# TERM first, KILL after the grace period; a group that is already gone is fine.
# ------------------------------------------------------------------------------

def _signal_group(process: subprocess.Popen, signal_number: int) -> None:
    try:
        os.killpg(process.pid, signal_number)
    except ProcessLookupError:
        return
    except PermissionError:
        return


def _stop_group(process: subprocess.Popen) -> tuple[str, str]:
    _signal_group(process, signal.SIGTERM)

    try:
        stdout_text, stderr_text = process.communicate(timeout=_GRACE_SECONDS)
    except subprocess.TimeoutExpired:
        _signal_group(process, signal.SIGKILL)

        try:
            stdout_text, stderr_text = process.communicate(timeout=_GRACE_SECONDS)
        except subprocess.TimeoutExpired:
            process.wait()

            return "", ""

    return stdout_text or "", stderr_text or ""


# ------------------------------------------------------------------------------
# run_timeout ARGUMENT_LIST SECONDS: runs a command, captures its output
# ------------------------------------------------------------------------------
# stdin is closed unless STDIN text is given. The command is found on the PATH of
# ENVIRON when one is passed. On a timeout the whole process group is stopped. A
# command that cannot be started reads as exit 127 with the reason in stderr.
# ------------------------------------------------------------------------------

def run_timeout(
    argument_list: list[str],
    seconds: float,
    environ: Mapping[str, str] | None = None,
    cwd: Path | str | None = None,
    stdin: str | None = None,
) -> CommandResult:
    try:
        process = subprocess.Popen(
            argument_list,
            env=environ,
            cwd=cwd,
            stdin=subprocess.DEVNULL if stdin is None else subprocess.PIPE,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            text=True,
            errors="replace",
            start_new_session=True,
        )
    except OSError as e:
        return CommandResult(_NOT_FOUND_EXIT_CODE, "", str(e), False)

    try:
        stdout_text, stderr_text = process.communicate(input=stdin, timeout=seconds)
    except subprocess.TimeoutExpired:
        stdout_text, stderr_text = _stop_group(process)

        return CommandResult(process.returncode, stdout_text, stderr_text, True)

    return CommandResult(process.returncode, stdout_text or "", stderr_text or "", False)


# ------------------------------------------------------------------------------
# run_streamed ARGUMENT_LIST SECONDS ENVIRON LOG_FILE: a long command, live
# ------------------------------------------------------------------------------
# stdout and stderr are merged; every line is echoed and appended to LOG_FILE as
# it comes, so a long build shows progress. A timer stops the group on a timeout.
# ------------------------------------------------------------------------------

def run_streamed(
    argument_list: list[str],
    seconds: float,
    environ: Mapping[str, str] | None,
    log_file: Path,
) -> CommandResult:
    try:
        process = subprocess.Popen(
            argument_list,
            env=environ,
            stdin=subprocess.DEVNULL,
            stdout=subprocess.PIPE,
            stderr=subprocess.STDOUT,
            text=True,
            errors="replace",
            start_new_session=True,
        )
    except OSError as e:
        return CommandResult(_NOT_FOUND_EXIT_CODE, str(e), "", False)

    timed_out_event = threading.Event()

    def stop_on_timeout() -> None:
        timed_out_event.set()
        _signal_group(process, signal.SIGTERM)

    def kill_on_timeout() -> None:
        _signal_group(process, signal.SIGKILL)

    stop_timer = threading.Timer(seconds, stop_on_timeout)
    kill_timer = threading.Timer(seconds + _GRACE_SECONDS, kill_on_timeout)
    stop_timer.start()
    kill_timer.start()
    line_list = []

    with open(log_file, "a", encoding="utf-8") as log_handle:
        for line in process.stdout:
            line_list.append(line)
            sys.stdout.write(line)
            sys.stdout.flush()
            log_handle.write(line)
            log_handle.flush()

    returncode = process.wait()
    stop_timer.cancel()
    kill_timer.cancel()

    return CommandResult(returncode, "".join(line_list), "", timed_out_event.is_set())


# ------------------------------------------------------------------------------
# run_sbx COMMAND ARGUMENT_LIST ENVIRON: runs a command of bin/ by name
# ------------------------------------------------------------------------------
# The command is found on the PATH of ENVIRON, which has the repo bin/ first, the
# way a user runs it.
# ------------------------------------------------------------------------------

def run_sbx(
    command: str,
    argument_list: list[str],
    environ: Mapping[str, str],
    seconds: int = 900,
) -> CommandResult:
    return run_timeout([command, *argument_list], seconds, environ)


# ------------------------------------------------------------------------------
# Docker
# ------------------------------------------------------------------------------

def docker_exec(container: str, script: str, seconds: int = 120, user: str | None = None) -> CommandResult:
    argument_list = ["docker", "exec"]

    if user is not None:
        argument_list += ["-u", user]

    argument_list += [container, "bash", "-c", script]

    return run_timeout(argument_list, seconds)


def inspect_container(container: str) -> dict | None:
    result = run_timeout(["docker", "container", "inspect", container], 60)

    if result.returncode != 0:
        return None

    try:
        inspected_list = json.loads(result.stdout)
    except json.JSONDecodeError:
        return None

    if not inspected_list:
        return None

    return inspected_list[0]


# ------------------------------------------------------------------------------
# one_bind_mount_problem CONTAINER SANDBOX_DIR: None when the mount is as built
# ------------------------------------------------------------------------------
# Exactly one mount, a bind at the workspace path, whose source ends in the
# sandbox directory's own name. Docker Desktop rewrites the front of the path, so
# only the last part is compared.
# ------------------------------------------------------------------------------

def one_bind_mount_problem(container: str, sandbox_dir: Path) -> str | None:
    inspected = inspect_container(container)

    if inspected is None:
        return f"{container} is not there"

    mount_list = inspected.get("Mounts", [])

    if len(mount_list) != 1:
        return f"{container} has {len(mount_list)} mounts, expected exactly one"

    mount = mount_list[0]

    if mount.get("Type") != "bind":
        return f"the mount of {container} is a {mount.get('Type')} mount, expected a bind mount"

    if mount.get("Destination") != _WORKSPACE_MOUNT:
        return f"the mount of {container} is at {mount.get('Destination')}, expected {_WORKSPACE_MOUNT}"

    source = str(mount.get("Source", ""))

    if os.path.basename(source.rstrip("/")) != sandbox_dir.name:
        return f"the mount source of {container} is {source}, which does not end in {sandbox_dir.name}"

    return None


# ------------------------------------------------------------------------------
# other_sbx_container_map EXCLUDED_NAME: every other sbx- container
# ------------------------------------------------------------------------------
# Name -> (id, start time). A scenario compares the map before and after a
# command, to prove the command touched no other sandbox.
# ------------------------------------------------------------------------------

def container_map_from_text(inspect_text: str, excluded_name: str) -> dict[str, tuple[str, str]]:
    container_map = {}

    for line in inspect_text.splitlines():
        field_list = line.split("\t")

        if len(field_list) != 3:
            continue

        name = field_list[0].lstrip("/")

        if name == excluded_name or not name.startswith("sbx-"):
            continue

        container_map[name] = (field_list[1], field_list[2])

    return container_map


def other_sbx_container_map(excluded_name: str) -> dict[str, tuple[str, str]]:
    listing = run_timeout(["docker", "ps", "-a", "--format", "{{.Names}}"], 60)

    if listing.returncode != 0:
        return {}

    name_list = []

    for name in listing.stdout.split():
        if name.startswith("sbx-") and name != excluded_name:
            name_list.append(name)

    if not name_list:
        return {}

    inspected = run_timeout(
        ["docker", "container", "inspect", "--format", "{{.Name}}\t{{.Id}}\t{{.State.StartedAt}}", *name_list],
        60,
    )

    return container_map_from_text(inspected.stdout, excluded_name)


# ------------------------------------------------------------------------------
# selfcheck_problem_list OUTPUT EXPECTED_COUNT: what is wrong with the output
# ------------------------------------------------------------------------------
# Every line is a PASS line, a FAIL line, an indented fix line or the closing
# summary; any other line is a problem. A FAIL line is listed with its fix. The
# test images carry a root certificate, so a check that says none was requested
# means the build lost it.
# ------------------------------------------------------------------------------

def selfcheck_problem_list(output: str, expected_count: int) -> list[str]:
    problem_list = []
    check_count = 0
    pending_fail = ""

    for line in output.splitlines():
        if pending_fail:
            if line.startswith(" ") and line.strip().startswith(_FIX_LINE_PREFIX):
                problem_list.append(f"{pending_fail}\n{line}")
                pending_fail = ""

                continue

            problem_list.append(pending_fail)
            pending_fail = ""

        if line.startswith("PASS: "):
            check_count += 1

            if "no extra root certificate requested" in line:
                problem_list.append(f"the test image should carry a root certificate: {line}")
        elif line.startswith("FAIL: "):
            check_count += 1
            pending_fail = line
        elif line.startswith("sbx-selfcheck: "):
            continue
        else:
            problem_list.append(f"unexpected line: {line}")

    if pending_fail:
        problem_list.append(pending_fail)

    if check_count != expected_count:
        problem_list.append(f"{check_count} check lines, expected {expected_count}")

    return problem_list


# ------------------------------------------------------------------------------
# The throwaway root certificate
# ------------------------------------------------------------------------------
# The private key is deleted at once; the certificate alone signs nothing. A
# certificate valid for another day is reused, so the test images keep their
# build cache.
# ------------------------------------------------------------------------------

def certificate_is_valid(cert_file: Path) -> bool:
    if not cert_file.is_file():
        return False

    result = run_timeout(["openssl", "x509", "-noout", "-checkend", "86400", "-in", str(cert_file)], 60)

    return result.returncode == 0


def make_root_certificate(cert_file: Path) -> None:
    cert_dir = cert_file.parent
    key_file = cert_dir / "root-ca.key"

    cert_dir.mkdir(mode=0o700, parents=True, exist_ok=True)
    os.chmod(cert_dir, 0o700)

    try:
        result = run_timeout(
            [
                "openssl", "req", "-x509", "-newkey", "rsa:2048", "-nodes", "-days", "3650",
                "-subj", "/CN=sbx-hosttest-root-ca", "-keyout", str(key_file), "-out", str(cert_file),
            ],
            120,
        )
    finally:
        key_file.unlink(missing_ok=True)

    if result.returncode != 0:
        raise RuntimeError(f"openssl could not make the test root certificate: {result.stderr.strip()}")


def certificate_fingerprint(cert_file: Path) -> str:
    result = run_timeout(["openssl", "x509", "-noout", "-fingerprint", "-sha256", "-in", str(cert_file)], 60)

    if result.returncode != 0:
        return ""

    text = result.stdout.strip()

    return text.partition("=")[2].replace(":", "").upper()
