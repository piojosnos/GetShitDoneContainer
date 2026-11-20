# ------------------------------------------------------------------------------
# clean.sh: frees Docker disk space and removes leftover host-test runs
# ------------------------------------------------------------------------------
# With no argument it only shows what it would remove; --yes removes it. This
# module and rm.py are the only host modules that delete anything, so what
# destroys data lives in two files. A test container goes only when its workspace
# mount lies in a host-test run directory; a sandbox of yours that is named like
# a test sandbox is kept. Volumes and containers that are not test containers are
# never touched.
# ------------------------------------------------------------------------------

import os
import shutil
import sys
from collections.abc import Mapping
from functools import partial
from pathlib import Path

from sbx.cli import SbxError, UsageError, run_command
from sbx.docker import Docker, require_docker, run_docker
from sbx.hosttest_names import (
    OLD_ROOT_CA_DIR_NAME,
    ROOT_CA_DIR_NAME,
    RUN_DIR_PREFIX,
    TEST_SANDBOX_PREFIX,
    temp_base_dir,
)
from sbx.names import container_name


# ------------------------------------------------------------------------------
# Constants
# ------------------------------------------------------------------------------
# A test container is named sbx-hosttest (the old single test sandbox) or starts
# with sbx-hosttest- (one per agent).
# ------------------------------------------------------------------------------

COMMAND_NAME = "clean.sh"
VERDICT_ABSENT = "absent"
VERDICT_REMOVE = "remove"
VERDICT_KEEP = "keep"
_USAGE_TEXT = "[--yes]"
_YES_OPTION = "--yes"
_WORKSPACE_DESTINATION = "/home/sandbox/workspace"
_OLD_TEST_CONTAINER_NAME = container_name(TEST_SANDBOX_PREFIX.rstrip("-"))
_TEST_CONTAINER_PREFIX = container_name(TEST_SANDBOX_PREFIX)
_ROOT_CA_DIR_NAME_LIST = [ROOT_CA_DIR_NAME, OLD_ROOT_CA_DIR_NAME]


# ------------------------------------------------------------------------------
# The directories under the temp base
# ------------------------------------------------------------------------------
# The run directories start with the run prefix. The test root certificate
# directories are reused from run to run and sit apart: the old one still starts
# with the run prefix, so it is left out of the run directory list by name and
# listed on its own line.
# ------------------------------------------------------------------------------

def _is_plain_dir(path: Path) -> bool:
    return path.is_dir() and not path.is_symlink()


def run_dir_list(temp_base: Path) -> list[Path]:
    dir_list = []

    for path in sorted(temp_base.glob(f"{RUN_DIR_PREFIX}*")):
        if path.name in _ROOT_CA_DIR_NAME_LIST:
            continue

        if _is_plain_dir(path):
            dir_list.append(path)

    return dir_list


def root_ca_dir_list(temp_base: Path) -> list[Path]:
    dir_list = []

    for name in _ROOT_CA_DIR_NAME_LIST:
        path = temp_base / name

        if _is_plain_dir(path):
            dir_list.append(path)

    return dir_list


# ------------------------------------------------------------------------------
# The verdict on one test container
# ------------------------------------------------------------------------------
# mount_source is the host directory mounted at the workspace, None when there is
# no container. Docker Desktop may report the temp directory with a /private
# prefix, so the source is searched for the temp base as given and as resolved.
# Only a source inside a run directory is removed; one inside a certificate
# directory is kept.
# ------------------------------------------------------------------------------

def _run_dir_name_in_source(mount_source: str, temp_base: Path) -> str:
    for base_text in [str(temp_base), os.path.realpath(temp_base)]:
        marker = f"{base_text.rstrip('/')}/"
        position = mount_source.find(f"{marker}{RUN_DIR_PREFIX}")

        if position >= 0:
            return mount_source[position + len(marker):].split("/")[0]

    return ""


def hosttest_container_verdict(name: str, mount_source: str | None, temp_base: Path) -> str:
    if mount_source is None:
        return VERDICT_ABSENT

    dir_name = _run_dir_name_in_source(mount_source, temp_base)

    if not dir_name or dir_name in _ROOT_CA_DIR_NAME_LIST:
        return VERDICT_KEEP

    return VERDICT_REMOVE


# ------------------------------------------------------------------------------
# The test containers
# ------------------------------------------------------------------------------

def _is_test_container_name(name: str) -> bool:
    return name == _OLD_TEST_CONTAINER_NAME or name.startswith(_TEST_CONTAINER_PREFIX)


def _test_container_name_list(docker: Docker) -> list[str]:
    result = docker(["ps", "-a", "--format", "{{.Names}}"], None, True)

    if result.returncode != 0:
        raise SbxError("docker ps failed; nothing was removed")

    name_list = []

    for line in result.stdout.splitlines():
        name = line.strip()

        if _is_test_container_name(name):
            name_list.append(name)

    return sorted(name_list)


def _mount_source(docker: Docker, name: str) -> str | None:
    format_text = (
        f'{{{{range .Mounts}}}}{{{{if eq .Destination "{_WORKSPACE_DESTINATION}"}}}}'
        "{{.Source}}{{end}}{{end}}"
    )
    result = docker(["container", "inspect", "--format", format_text, name], None, True)

    if result.returncode != 0:
        return None

    return result.stdout.strip()


def _verdict_map(docker: Docker, name_list: list[str], temp_base: Path) -> dict[str, str]:
    verdict_by_name_map = {}

    for name in name_list:
        mount_source = _mount_source(docker, name)
        verdict_by_name_map[name] = hosttest_container_verdict(name, mount_source, temp_base)

    return verdict_by_name_map


# ------------------------------------------------------------------------------
# What a dry run shows
# ------------------------------------------------------------------------------
# The dry run lists all images; docker image prune -a decides which of them go.
# ------------------------------------------------------------------------------

def _print_dir_section(title: str, dir_list: list[Path]) -> None:
    print(f"=== {title}")

    if not dir_list:
        print("(none)")

    for path in dir_list:
        print(path)

    print()


def _show_state(
    docker: Docker,
    verdict_by_name_map: dict[str, str],
    run_dir_path_list: list[Path],
    root_ca_path_list: list[Path],
) -> None:
    print("=== Docker disk use", flush=True)
    docker(["system", "df"], None, False)
    print()
    print("=== Containers (all kept, except a test container that mounts a host-test run directory)", flush=True)
    docker(["ps", "-a", "--format", "{{.Names}}  {{.Image}}  {{.Status}}"], None, False)

    for name, verdict in verdict_by_name_map.items():
        if verdict == VERDICT_REMOVE:
            print(f"{name} mounts a host-test run directory: --yes removes it")
        elif verdict == VERDICT_KEEP:
            print(f"{name} does not mount a host-test run directory: --yes keeps it")

    print()
    _print_dir_section("Host-test run directories", run_dir_path_list)
    _print_dir_section("Test root certificate directories", root_ca_path_list)
    print("=== Images", flush=True)
    docker(["image", "ls"], None, False)
    print("--yes runs docker image prune -a: it removes every image no container uses")
    print()


# ------------------------------------------------------------------------------
# What --yes removes
# ------------------------------------------------------------------------------
# A container that cannot be removed stops the run before any directory goes: its
# mount may still be in use. A directory that cannot be removed is reported and
# the rest goes on; the run then ends with a refusal naming it.
# ------------------------------------------------------------------------------

def _remove_test_containers(docker: Docker, verdict_by_name_map: dict[str, str]) -> None:
    print("=== Removing the test containers", flush=True)

    removed_count = 0

    for name, verdict in verdict_by_name_map.items():
        if verdict == VERDICT_KEEP:
            print(f"{name} does not mount a host-test run directory; left alone, with its network")
            continue

        if verdict == VERDICT_ABSENT:
            continue

        network_name = f"{name}_default"

        sys.stdout.flush()

        if docker(["rm", "-f", name], None, False).returncode != 0:
            raise SbxError(f"docker rm -f {name} failed; no directory was removed")

        removed_count += 1

        if docker(["network", "rm", network_name], None, True).returncode != 0:
            print(f"(no {network_name} network)")

    if removed_count == 0:
        print("(no test container to remove)")

    print()


def _remove_dir_list(title: str, dir_list: list[Path]) -> list[Path]:
    print(f"=== {title}")

    if not dir_list:
        print("(none)")

    failed_list = []

    for path in dir_list:
        try:
            shutil.rmtree(path)
        except OSError as problem:
            print(f"{COMMAND_NAME}: could not remove {path}: {problem}", file=sys.stderr)
            failed_list.append(path)
            continue

        print(f"removed {path}")

    print()

    return failed_list


# ------------------------------------------------------------------------------
# The build cache and the unused images
# ------------------------------------------------------------------------------
# Other containers, their images and all volumes are kept. The sbx images go too
# when no container uses them, under every tag; build.sh and host-test.sh build
# them again.
# ------------------------------------------------------------------------------

def _remove_unused_images(docker: Docker) -> None:
    print("=== Removing the build cache", flush=True)
    docker(["builder", "prune", "-a", "-f"], None, False)
    print()
    print("=== Removing images no container uses", flush=True)
    docker(["image", "prune", "-a", "-f"], None, False)
    print()


# ------------------------------------------------------------------------------
# The command
# ------------------------------------------------------------------------------

def _parse_arguments(argument_list: list[str]) -> bool:
    if argument_list == []:
        return False

    if argument_list == [_YES_OPTION]:
        return True

    raise UsageError(_USAGE_TEXT)


def _clean(argument_list: list[str], environ: Mapping[str, str], docker: Docker) -> None:
    remove = _parse_arguments(argument_list)

    require_docker(docker)

    temp_base = temp_base_dir(environ)
    name_list = _test_container_name_list(docker)
    verdict_by_name_map = _verdict_map(docker, name_list, temp_base)
    run_dir_path_list = run_dir_list(temp_base)
    root_ca_path_list = root_ca_dir_list(temp_base)

    _show_state(docker, verdict_by_name_map, run_dir_path_list, root_ca_path_list)

    if not remove:
        print(f"Dry run: nothing removed. Run ./{COMMAND_NAME} --yes to clean up.")

        return

    _remove_test_containers(docker, verdict_by_name_map)

    failed_list = _remove_dir_list("Removing host-test run directories", run_dir_path_list)
    failed_list += _remove_dir_list("Removing test root certificate directories", root_ca_path_list)

    _remove_unused_images(docker)
    print("=== Docker disk use after", flush=True)
    docker(["system", "df"], None, False)

    if failed_list:
        raise SbxError("some directories could not be removed; the messages above name them")


def main(
    argument_list: list[str],
    environ: Mapping[str, str] = os.environ,
    docker: Docker = run_docker,
) -> int:
    return run_command(COMMAND_NAME, partial(_clean, argument_list, environ, docker))


# ------------------------------------------------------------------------------
# Main / Entry Point
# ------------------------------------------------------------------------------

if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
