# --------------------------------------------------------------------------------
# host-test.sh: the host run of every test suite, with a log kept as it comes
# --------------------------------------------------------------------------------
# Usage: ./host-test.sh [--keep]   (exit 0 = every test passed)
# --keep leaves the test sandboxes and the run directory to look around after a
# failure. The run builds and checks the test images (tag test); it never builds,
# runs or removes the images your sandboxes run.
# --------------------------------------------------------------------------------

import os
import re
import subprocess
import sys
from collections.abc import Callable, Mapping
from datetime import datetime
from pathlib import Path
from typing import TextIO

from sbx.cli import REPO_DIR, UsageError
from sbx.docker import Docker, run_docker
from sbx.names import KNOWN_AGENT_LIST, agent_image, base_image


# --------------------------------------------------------------------------------
# Constants
# --------------------------------------------------------------------------------
# The integration suite runs before the guard: the guard's linter rules run from
# sbx-base:test, which the integration session builds. The sbx unit tests come
# first because they need no Docker and are the fastest to fail.
# --------------------------------------------------------------------------------

COMMAND_NAME = "host-test.sh"
LOG_NAME = "host-test.log"
SUITE_PATH_LIST = ["tests/unit/sbx", "tests/integration", "tests/guard"]
_TEST_TAG = "test"
_USAGE_TEXT = "[--keep]"
_KEEP_OPTION = "--keep"
_COMPOSE_MESSAGE = "Docker Compose v2 or newer is required; install Docker Desktop"
_COMPOSE_VERSION_PATTERN = re.compile(r"v?([0-9]+)(\.|$)")
_MINIMUM_COMPOSE_MAJOR = 2
_USAGE_EXIT_CODE = 2
_REFUSAL_EXIT_CODE = 1
_INTERRUPTED_EXIT_CODE = 130


# --------------------------------------------------------------------------------
# Docker Compose version
# --------------------------------------------------------------------------------
# Compose 2.x and the later 5.x pass, as does a v prefix; 1.x, empty text and
# anything that is not a version fail.
# --------------------------------------------------------------------------------

def compose_version_ok(version_text: str) -> bool:
    found = _COMPOSE_VERSION_PATTERN.match(version_text.strip())

    if found is None:
        return False

    return int(found.group(1)) >= _MINIMUM_COMPOSE_MAJOR


# --------------------------------------------------------------------------------
# The pytest child
# --------------------------------------------------------------------------------
# Every scenario runs, so the summary lists every failure; the run is never
# told to stop at the first one.
# --------------------------------------------------------------------------------

def pytest_argument_list(keep: bool) -> list[str]:
    argument_list = ["-m", "pytest", "-v", "-s", "-p", "no:cacheprovider", *SUITE_PATH_LIST]

    if keep:
        argument_list.append(_KEEP_OPTION)

    return argument_list


def _child_environ(environ: Mapping[str, str]) -> dict[str, str]:
    child_environ = dict(environ)
    child_environ["SBX_IMAGE_TAG"] = _TEST_TAG
    child_environ["PYTHONUNBUFFERED"] = "1"

    return child_environ


# --------------------------------------------------------------------------------
# Output: the terminal and the log, one line at a time
# --------------------------------------------------------------------------------
# Each line is flushed to both, so a long build shows progress and the log is
# readable while the run is still going.
# --------------------------------------------------------------------------------

def _emit(text: str, output: TextIO, log_handle: TextIO) -> None:
    output.write(text)
    output.flush()
    log_handle.write(text)
    log_handle.flush()


def _emit_line(text: str, output: TextIO, log_handle: TextIO) -> None:
    _emit(f"{text}\n", output, log_handle)


def run_and_log(
    argument_list: list[str],
    environ: Mapping[str, str],
    output: TextIO,
    log_handle: TextIO,
    popen: Callable[..., subprocess.Popen] = subprocess.Popen,
    cwd: Path | None = None,
) -> int:
    process = popen(
        argument_list,
        env=dict(environ),
        cwd=cwd,
        stdin=subprocess.DEVNULL,
        stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT,
        text=True,
        errors="replace",
    )

    try:
        for line in process.stdout:
            _emit(line, output, log_handle)
    except KeyboardInterrupt:
        # The child got the same signal; wait for it to run its cleanup.
        process.wait()

        return _INTERRUPTED_EXIT_CODE

    return process.wait()


# --------------------------------------------------------------------------------
# Preflight and context
# --------------------------------------------------------------------------------

def _compose_is_v2(docker: Docker) -> bool:
    result = docker(["compose", "version", "--short"], None, True)

    if result.returncode != 0:
        return False

    return compose_version_ok(result.stdout)


def _git_text(repo_dir: Path, argument_list: list[str]) -> str:
    try:
        completed = subprocess.run(
            ["git", *argument_list],
            cwd=repo_dir,
            stdin=subprocess.DEVNULL,
            capture_output=True,
            text=True,
            errors="replace",
            check=False,
        )
    except OSError:
        return ""

    if completed.returncode != 0:
        return ""

    return completed.stdout.strip()


def _image_line() -> str:
    image_list = [base_image(_TEST_TAG)]

    for agent in KNOWN_AGENT_LIST:
        image_list.append(agent_image(agent, _TEST_TAG))

    return f"images: {', '.join(image_list)}"


def _docker_text(docker: Docker, argument_list: list[str]) -> str:
    result = docker(argument_list, None, True)

    if result.returncode != 0:
        return f"docker {' '.join(argument_list)}: failed (exit {result.returncode})"

    return result.stdout.strip()


def _write_context(docker: Docker, repo_dir: Path, output: TextIO, log_handle: TextIO) -> None:
    branch = _git_text(repo_dir, ["rev-parse", "--abbrev-ref", "HEAD"]) or "unknown"
    commit = _git_text(repo_dir, ["rev-parse", "--short", "HEAD"]) or "unknown"

    _emit_line(datetime.now().astimezone().strftime("%a %b %d %H:%M:%S %Z %Y"), output, log_handle)
    _emit_line(f"branch {branch}, commit {commit}", output, log_handle)
    _emit_line(_image_line(), output, log_handle)

    for status_line in _git_text(repo_dir, ["status", "--short"]).splitlines():
        _emit_line(status_line, output, log_handle)

    _emit_line(_docker_text(docker, ["--version"]), output, log_handle)
    _emit_line(_docker_text(docker, ["compose", "version"]), output, log_handle)


# --------------------------------------------------------------------------------
# Arguments
# --------------------------------------------------------------------------------

def _parse_keep(argument_list: list[str]) -> bool:
    if argument_list == []:
        return False

    if argument_list == [_KEEP_OPTION]:
        return True

    raise UsageError(_USAGE_TEXT)


# --------------------------------------------------------------------------------
# The run
# --------------------------------------------------------------------------------

def _run(
    keep: bool,
    environ: Mapping[str, str],
    docker: Docker,
    repo_dir: Path,
    output: TextIO,
    log_handle: TextIO,
) -> int:
    log_path = repo_dir / LOG_NAME

    if not _compose_is_v2(docker):
        _emit_line(_COMPOSE_MESSAGE, output, log_handle)

        return _REFUSAL_EXIT_CODE

    _write_context(docker, repo_dir, output, log_handle)

    code = run_and_log(
        [sys.executable, *pytest_argument_list(keep)],
        _child_environ(environ),
        output,
        log_handle,
        cwd=repo_dir,
    )

    if code == 0:
        _emit_line(f"{COMMAND_NAME}: every test passed; log: {log_path}", output, log_handle)
    else:
        _emit_line(
            f"{COMMAND_NAME}: pytest exited {code}; the failures are listed above; log: {log_path}",
            output,
            log_handle,
        )

    return code


def main(
    argument_list: list[str],
    output: TextIO,
    environ: Mapping[str, str] = os.environ,
    docker: Docker = run_docker,
    repo_dir: Path = REPO_DIR,
) -> int:
    try:
        keep = _parse_keep(argument_list)
    except UsageError as e:
        print(f"Usage: {COMMAND_NAME} {e.args_text}", file=sys.stderr)

        return _USAGE_EXIT_CODE

    with open(repo_dir / LOG_NAME, "w", encoding="utf-8") as log_handle:
        return _run(keep, environ, docker, repo_dir, output, log_handle)


# --------------------------------------------------------------------------------
# Main / Entry Point
# --------------------------------------------------------------------------------

if __name__ == "__main__":
    sys.exit(main(sys.argv[1:], sys.stdout))
