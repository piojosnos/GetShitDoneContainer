# ------------------------------------------------------------------------------
# Tests of the host launchers: shape, mode and the refusal of a wrong argument
# ------------------------------------------------------------------------------
# A host launcher is a #!/bin/sh file of two lines that runs one Python module
# through uv. Each one is run as a process from a directory outside the repo, as
# a user runs it from PATH. None of the cases needs Docker.
# ------------------------------------------------------------------------------

import json
import os
import subprocess
from pathlib import Path

import pytest

from sbx_helpers import REPO_DIR

LAUNCHER_BAD_ARGUMENTS_MAP = {
    "sbx-add": ["only-one"],
    "sbx-list": ["extra"],
    "sbx-migrate-registry": ["extra"],
}
_LAUNCHER_SHEBANG = "#!/bin/sh"
_ROOT_LAUNCHER_NAME_LIST = ["build.sh", "clean.sh", "host-test.sh"]


# ------------------------------------------------------------------------------
# Finding the launchers
# ------------------------------------------------------------------------------

def _first_line(file: Path) -> str:
    with open(file, encoding="utf-8", errors="replace") as handle:
        return handle.readline().rstrip("\n")


def find_launcher_list() -> list[Path]:
    candidate_list = []

    for file in sorted((REPO_DIR / "bin").iterdir()):
        candidate_list.append(file)

    for name in _ROOT_LAUNCHER_NAME_LIST:
        candidate_list.append(REPO_DIR / name)

    launcher_list = []

    for file in candidate_list:
        if file.is_file() and _first_line(file) == _LAUNCHER_SHEBANG:
            launcher_list.append(file)

    return launcher_list


LAUNCHER_LIST = find_launcher_list()


def _launcher_environ(config: Path) -> dict[str, str]:
    environ = dict(os.environ)
    environ.pop("VIRTUAL_ENV", None)
    environ.pop("SBX_IMAGE_TAG", None)
    environ["SBX_CONFIG_DIR"] = str(config)

    return environ


# ------------------------------------------------------------------------------
# Cases
# ------------------------------------------------------------------------------

def test_the_launcher_list_is_not_empty():
    assert LAUNCHER_LIST != []


@pytest.mark.parametrize("launcher", LAUNCHER_LIST, ids=[file.name for file in LAUNCHER_LIST])
def test_a_launcher_refuses_a_wrong_argument_count_with_a_usage_line(launcher, tmp_path):
    assert launcher.name in LAUNCHER_BAD_ARGUMENTS_MAP

    result = subprocess.run(
        [str(launcher), *LAUNCHER_BAD_ARGUMENTS_MAP[launcher.name]],
        cwd=tmp_path,
        env=_launcher_environ(tmp_path / "config1"),
        stdin=subprocess.DEVNULL,
        capture_output=True,
        text=True,
        check=False,
    )

    assert result.returncode == 2
    assert result.stderr.splitlines()[0].startswith(f"Usage: {launcher.name}")


@pytest.mark.parametrize("launcher", LAUNCHER_LIST, ids=[file.name for file in LAUNCHER_LIST])
def test_a_launcher_is_two_lines_that_run_one_module_through_uv_without_the_project(launcher):
    line_list = launcher.read_text(encoding="utf-8").splitlines()

    assert len(line_list) == 2
    assert line_list[0] == _LAUNCHER_SHEBANG
    assert line_list[1].startswith("exec uv run --directory ")
    assert " --no-project " in line_list[1] or " --isolated --frozen " in line_list[1]
    assert line_list[1].endswith(' "$@"')


def test_the_migrate_launcher_converts_an_old_entry_from_another_directory(tmp_path):
    registry = tmp_path / "config1" / "sandboxes"
    registry.mkdir(parents=True)
    old_file = registry / "sbx1"
    old_file.write_text("SBX_DIR=/x/one dir\nSBX_AGENT=cursor\n")
    before = old_file.read_bytes()

    result = subprocess.run(
        [str(REPO_DIR / "bin" / "sbx-migrate-registry")],
        cwd=tmp_path,
        env=_launcher_environ(tmp_path / "config1"),
        stdin=subprocess.DEVNULL,
        capture_output=True,
        text=True,
        check=False,
    )

    assert result.returncode == 0
    assert json.loads((registry / "sbx1.json").read_text()) == {"path": "/x/one dir", "agent": "cursor"}
    assert old_file.read_bytes() == before


def test_the_add_launcher_stores_a_path_with_a_space_and_a_non_ascii_letter_as_given(tmp_path):
    registry = tmp_path / "config1" / "sandboxes"
    registry.mkdir(parents=True)
    path = f"{tmp_path}/one dir/caf\u00e9"

    result = subprocess.run(
        [str(REPO_DIR / "bin" / "sbx-add"), "sbx1", path],
        cwd=tmp_path,
        env=_launcher_environ(tmp_path / "config1"),
        stdin=subprocess.DEVNULL,
        capture_output=True,
        text=True,
        check=False,
    )

    assert result.returncode == 0
    assert json.loads((registry / "sbx1.json").read_text(encoding="utf-8")) == {"path": path, "agent": "claude"}
    assert (tmp_path / "one dir" / "caf\u00e9" / "sbx1").is_dir()
