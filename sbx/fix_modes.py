# ------------------------------------------------------------------------------
# sbx-fix-modes: sets the mode of every tracked file to what git committed, on the
# host and in the sandbox
# ------------------------------------------------------------------------------
# Docker Desktop keeps the mode the sandbox sees in the extended attribute
# user.containers.override_stat (uid:gid:mode) of the host file. A chmod in the
# sandbox changes only that attribute, so the two sides drift apart. This sets the
# host mode and the attribute's mode to 644 or 755 from the git index, so the
# host, the sandbox and git agree. A file without the attribute gets the host mode
# only.
# ------------------------------------------------------------------------------

import os
import shutil
import stat
import subprocess
import sys
from collections.abc import Callable, Mapping
from dataclasses import dataclass
from functools import partial
from pathlib import Path

from sbx.cli import SbxError, UsageError, run_command
from sbx.names import check_name, image_tag
from sbx.registry import config_dir, read_entry, registry_dir


# ------------------------------------------------------------------------------
# Constants
# ------------------------------------------------------------------------------

COMMAND_NAME = "sbx-fix-modes"
_OVERRIDE_NAME = "user.containers.override_stat"
_MODE_BY_GIT_MODE_MAP = {"100644": 0o644, "100755": 0o755}


# ------------------------------------------------------------------------------
# The xattr command
# ------------------------------------------------------------------------------
# The attribute is read and written through a function that takes the arguments of
# the xattr command and answers its exit code and output. Left out, main looks
# xattr up on the PATH when it runs; a test passes its own function.
# ------------------------------------------------------------------------------

@dataclass(frozen=True)
class XattrResult:
    returncode: int
    stdout: str


XattrFunction = Callable[[list[str]], XattrResult]


def _run_xattr(xattr_path: str, argument_list: list[str]) -> XattrResult:
    result = subprocess.run(
        [xattr_path, *argument_list],
        stdin=subprocess.DEVNULL,
        stdout=subprocess.PIPE,
        stderr=subprocess.DEVNULL,
        text=True,
        errors="replace",
        check=False,
    )

    return XattrResult(result.returncode, result.stdout)


def _find_xattr_function(environ: Mapping[str, str]) -> XattrFunction | None:
    xattr_path = shutil.which("xattr", path=environ.get("PATH"))

    if xattr_path is None:
        return None

    return partial(_run_xattr, xattr_path)


# ------------------------------------------------------------------------------
# Git
# ------------------------------------------------------------------------------
# One ls-files run lists the index; its records are parsed here, so a path with a
# space or a line break in it is read whole.
# ------------------------------------------------------------------------------

def _check_top_of_repository(project_dir: str) -> None:
    result = subprocess.run(
        ["git", "-C", project_dir, "rev-parse", "--show-prefix"],
        stdin=subprocess.DEVNULL,
        capture_output=True,
        text=True,
        errors="replace",
        check=False,
    )

    if result.returncode != 0 or result.stdout.strip() != "":
        raise SbxError(f"{project_dir} is not the top directory of a git repository")


def _read_index(project_dir: str) -> list[tuple[str, str]]:
    result = subprocess.run(
        ["git", "-C", project_dir, "ls-files", "-s", "-z"],
        stdin=subprocess.DEVNULL,
        capture_output=True,
        check=False,
    )

    if result.returncode != 0:
        raise SbxError(f"git ls-files failed in {project_dir}")

    record_list = []

    for record in result.stdout.split(b"\0"):
        if not record:
            continue

        info_bytes, _, path_bytes = record.partition(b"\t")
        git_mode = os.fsdecode(info_bytes).split(" ", 1)[0]

        record_list.append((git_mode, os.fsdecode(path_bytes)))

    return record_list


# ------------------------------------------------------------------------------
# One file
# ------------------------------------------------------------------------------
# The host mode comes first: macOS refuses to write an attribute on a read-only
# file. Each function says whether it changed something.
# ------------------------------------------------------------------------------

def _fix_host_mode(path: str, git_mode: str) -> bool:
    wanted_mode = _MODE_BY_GIT_MODE_MAP[git_mode]

    if stat.S_IMODE(os.stat(path).st_mode) == wanted_mode:
        return False

    try:
        os.chmod(path, wanted_mode)
    except OSError:
        raise SbxError(f"could not change the mode of {path}") from None

    return True


def _fix_sandbox_mode(path: str, git_mode: str, xattr_function: XattrFunction) -> bool:
    result = xattr_function(["-p", _OVERRIDE_NAME, path])

    if result.returncode != 0:
        return False

    current_value = result.stdout.rstrip("\n")
    wanted_value = f"{current_value.rsplit(':', 1)[0]}:0{git_mode}"

    if current_value == wanted_value:
        return False

    if xattr_function(["-w", _OVERRIDE_NAME, wanted_value, path]).returncode != 0:
        raise SbxError(f"xattr could not write the mode of {path}")

    return True


# ------------------------------------------------------------------------------
# The command
# ------------------------------------------------------------------------------

def _fix_modes(
    argument_list: list[str], environ: Mapping[str, str], xattr_function: XattrFunction | None
) -> None:
    if len(argument_list) != 1:
        raise UsageError("NAME")

    name = argument_list[0]
    registry = registry_dir(config_dir(environ))

    image_tag(environ, COMMAND_NAME)
    check_name(name)

    entry = read_entry(registry, name)
    project_dir = f"{entry.path}/{name}"

    _check_top_of_repository(project_dir)

    if xattr_function is None:
        xattr_function = _find_xattr_function(environ)

    host_count = 0
    sandbox_count = 0

    for git_mode, relative_path in _read_index(project_dir):
        path = f"{project_dir}/{relative_path}"

        if git_mode not in _MODE_BY_GIT_MODE_MAP:
            continue

        if os.path.islink(path) or not os.path.isfile(path):
            continue

        if _fix_host_mode(path, git_mode):
            host_count += 1

        if xattr_function is not None and _fix_sandbox_mode(path, git_mode, xattr_function):
            sandbox_count += 1

    print(f"{COMMAND_NAME}: set {host_count} host modes and {sandbox_count} sandbox modes from git in {project_dir}")

    if xattr_function is None:
        print(f"{COMMAND_NAME}: xattr is not installed, so the sandbox modes were not looked at")


def main(
    argument_list: list[str],
    environ: Mapping[str, str] = os.environ,
    xattr_function: XattrFunction | None = None,
) -> int:
    return run_command(COMMAND_NAME, partial(_fix_modes, argument_list, environ, xattr_function))


# ------------------------------------------------------------------------------
# Main / Entry Point
# ------------------------------------------------------------------------------

if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
