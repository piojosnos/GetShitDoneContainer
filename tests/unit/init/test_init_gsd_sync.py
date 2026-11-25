# --------------------------------------------------------------------------------
# Tests of the GSD sync step
# --------------------------------------------------------------------------------
# A stand-in installer on a temp PATH runs for real in its own session; one test
# runs the image's installer itself when it is there.
# --------------------------------------------------------------------------------

import os
import shutil
import time
from pathlib import Path

import pytest

import hints
from gsd_sync import gsd_sync_result
from init_helpers import REPO_DIR, environment_with, process_is_gone, write_stand_in

STAND_IN_NAME = "gsd-core-stand-in"
RECORDING_BODY = """printf '%s\\n' "$@" > "$STAND_IN_ARGS_FILE"
if read line; then
  echo "got: $line" > "$STAND_IN_STDIN_FILE"
else
  echo "end of file" > "$STAND_IN_STDIN_FILE"
fi
echo "line one"
echo "last words" >&2
exit "${STAND_IN_EXIT:-0}"
"""
SLEEPING_BODY = """sleep 30 &
echo $! > "$STAND_IN_GRANDCHILD_FILE"
sleep 30
"""


# --------------------------------------------------------------------------------
# Helpers
# --------------------------------------------------------------------------------

def stand_in_environment(tmp_path: Path, body: str, exit_code: int = 0) -> dict[str, str]:
    bin_dir = tmp_path / "bin1"
    bin_dir.mkdir(exist_ok=True)
    write_stand_in(bin_dir, STAND_IN_NAME, body)
    environment_map = environment_with(bin_dir)
    environment_map["STAND_IN_ARGS_FILE"] = str(tmp_path / "args1.txt")
    environment_map["STAND_IN_STDIN_FILE"] = str(tmp_path / "stdin1.txt")
    environment_map["STAND_IN_GRANDCHILD_FILE"] = str(tmp_path / "grandchild1.txt")
    environment_map["STAND_IN_EXIT"] = str(exit_code)

    return environment_map


def log_file_list(log_dir: Path) -> list[Path]:
    return sorted(log_dir.glob("sbx-init-gsd-*.log"))


def pinned_gsd_version() -> str:
    for line in (REPO_DIR / "versions.env").read_text().splitlines():
        if line.startswith("GSD_CORE_VERSION="):
            return line.split("=", 1)[1].strip()

    raise AssertionError("versions.env has no GSD_CORE_VERSION")


# --------------------------------------------------------------------------------
# The installer call
# --------------------------------------------------------------------------------

def test_the_installer_gets_the_agent_option_global_and_the_config_dir(tmp_path):
    environment_map = stand_in_environment(tmp_path, RECORDING_BODY)
    config1 = tmp_path / "config1"

    gsd_sync_result(config1, "--claude", STAND_IN_NAME, environment_map=environment_map, log_dir=tmp_path)

    argument_list = (tmp_path / "args1.txt").read_text().splitlines()
    assert argument_list == ["--claude", "--global", "--config-dir", str(config1)]


def test_the_installer_reads_an_already_closed_stdin(tmp_path):
    environment_map = stand_in_environment(tmp_path, RECORDING_BODY)

    gsd_sync_result(tmp_path / "config1", "--claude", STAND_IN_NAME, environment_map=environment_map, log_dir=tmp_path)

    assert (tmp_path / "stdin1.txt").read_text().strip() == "end of file"


# --------------------------------------------------------------------------------
# Outcomes
# --------------------------------------------------------------------------------

def test_exit_zero_passes_names_the_dir_and_leaves_no_log(tmp_path):
    environment_map = stand_in_environment(tmp_path, RECORDING_BODY)
    config1 = tmp_path / "config1"
    log_dir1 = tmp_path / "logs1"
    log_dir1.mkdir()

    result = gsd_sync_result(config1, "--claude", STAND_IN_NAME, environment_map=environment_map, log_dir=log_dir1)

    assert result.passed
    assert str(config1) in result.detail
    assert log_file_list(log_dir1) == []


def test_a_non_zero_exit_fails_with_the_code_the_last_line_and_the_kept_log(tmp_path):
    environment_map = stand_in_environment(tmp_path, RECORDING_BODY, exit_code=3)
    log_dir1 = tmp_path / "logs1"
    log_dir1.mkdir()

    result = gsd_sync_result(
        tmp_path / "config1", "--claude", STAND_IN_NAME, environment_map=environment_map, log_dir=log_dir1
    )

    kept_list = log_file_list(log_dir1)
    assert not result.passed
    assert "exited 3" in result.detail
    assert "last words" in result.detail
    assert len(kept_list) == 1
    assert str(kept_list[0]) in result.detail
    assert str(kept_list[0]) in result.hint
    assert "sbx-init again" in result.hint
    assert "line one" in kept_list[0].read_text()


def test_the_time_limit_stops_the_installer_and_everything_it_started(tmp_path):
    environment_map = stand_in_environment(tmp_path, SLEEPING_BODY)
    log_dir1 = tmp_path / "logs1"
    log_dir1.mkdir()
    started = time.monotonic()

    result = gsd_sync_result(
        tmp_path / "config1",
        "--claude",
        STAND_IN_NAME,
        time_limit_seconds=1,
        environment_map=environment_map,
        log_dir=log_dir1,
    )

    grandchild_id = int((tmp_path / "grandchild1.txt").read_text())
    assert time.monotonic() - started < 10
    assert not result.passed
    assert "did not finish within 1 s and was stopped" in result.detail
    assert str(log_file_list(log_dir1)[0]) in result.detail
    assert process_is_gone(grandchild_id)


def test_a_dir_that_cannot_be_made_fails_and_the_installer_never_runs(tmp_path):
    environment_map = stand_in_environment(tmp_path, RECORDING_BODY)
    blocker1 = tmp_path / "blocker1"
    blocker1.write_text("a file where a directory is needed")

    result = gsd_sync_result(
        blocker1 / "config1", "--claude", STAND_IN_NAME, environment_map=environment_map, log_dir=tmp_path
    )

    assert not result.passed
    assert str(blocker1 / "config1") in result.detail
    assert result.hint == hints.state_writable_hint()
    assert not (tmp_path / "args1.txt").exists()


@pytest.mark.skipif(os.geteuid() == 0, reason="root can make a directory under a read-only parent")
def test_a_config_dir_under_a_read_only_parent_fails_and_the_installer_never_runs(tmp_path):
    environment_map = stand_in_environment(tmp_path, RECORDING_BODY)
    parent1 = tmp_path / "parent1"
    parent1.mkdir()
    parent1.chmod(0o500)

    try:
        result = gsd_sync_result(
            parent1 / "config1", "--claude", STAND_IN_NAME, environment_map=environment_map, log_dir=tmp_path
        )
    finally:
        parent1.chmod(0o700)

    assert not result.passed
    assert str(parent1 / "config1") in result.detail
    assert not (tmp_path / "args1.txt").exists()


def test_an_installer_that_is_not_on_path_fails_with_the_rebuild_hint(tmp_path):
    empty1 = tmp_path / "empty1"
    empty1.mkdir()
    log_dir1 = tmp_path / "logs1"
    log_dir1.mkdir()

    result = gsd_sync_result(
        tmp_path / "config1",
        "--claude",
        "gsd-core-not-there",
        environment_map={"PATH": str(empty1)},
        log_dir=log_dir1,
    )

    assert not result.passed
    assert "gsd-core-not-there is not on PATH" in result.detail
    assert result.hint == hints.rebuild_hint()
    assert log_file_list(log_dir1) == []


# --------------------------------------------------------------------------------
# The image's own installer
# --------------------------------------------------------------------------------

@pytest.mark.skipif(shutil.which("gsd-core") is None, reason="gsd-core is not installed in this environment")
def test_the_image_installer_syncs_the_pinned_version_offline(tmp_path):
    home1 = tmp_path / "home1"
    home1.mkdir()
    environment_map = dict(os.environ)
    environment_map["HOME"] = str(home1)
    config1 = tmp_path / "claude1"

    result = gsd_sync_result(config1, "--claude", environment_map=environment_map, log_dir=tmp_path)

    assert result.passed, result.detail
    assert (config1 / "gsd-core" / "VERSION").read_text().strip() == pinned_gsd_version()
