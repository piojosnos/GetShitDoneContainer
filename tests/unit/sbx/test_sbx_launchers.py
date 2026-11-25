# --------------------------------------------------------------------------------
# Tests of the host launchers: shape, mode and the refusal of a wrong argument
# --------------------------------------------------------------------------------
# A host launcher is a #!/bin/sh file of two lines that runs one Python module
# through uv. Each one is run as a process from a directory outside the repo, as
# a user runs it from PATH. None of the cases needs Docker.
# --------------------------------------------------------------------------------

import json
import os
import subprocess
from pathlib import Path

import pytest

from sbx import add as add_module
from sbx import build as build_module
from sbx import fix_modes as fix_modes_module
from sbx import list_sandboxes as list_module
from sbx import rm as rm_module
from sbx import shell as shell_module
from sbx import start as start_module
from sbx import stop as stop_module
from sbx import upgrade as upgrade_module
from sbx_helpers import REPO_DIR, DockerRecorder

LAUNCHER_BAD_ARGUMENTS_MAP = {
    "sbx-add": ["only-one"],
    "sbx-list": ["extra"],
    "sbx-migrate-registry": ["extra"],
    "sbx-start": [],
    "sbx-stop": [],
    "sbx-shell": [],
    "sbx-upgrade": [],
    "sbx-rm": [],
    "sbx-fix-modes": [],
    "build.sh": None,
    "clean.sh": ["--bogus"],
    "host-test.sh": ["--bogus"],
}
_LAUNCHER_SHEBANG = "#!/bin/sh"
_ROOT_LAUNCHER_NAME_LIST = ["build.sh", "clean.sh", "host-test.sh"]


# --------------------------------------------------------------------------------
# Finding the launchers
# --------------------------------------------------------------------------------

def _first_line(file: Path) -> str:
    with open(file, encoding="utf-8", errors="replace") as handle:
        return handle.readline().rstrip("\n")


# --------------------------------------------------------------------------------

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


# --------------------------------------------------------------------------------
# Cases
# --------------------------------------------------------------------------------

def test_the_launcher_list_is_not_empty():
    assert LAUNCHER_LIST != []


# --------------------------------------------------------------------------------

@pytest.mark.parametrize("launcher", LAUNCHER_LIST, ids=[file.name for file in LAUNCHER_LIST])
def test_a_launcher_refuses_a_wrong_argument_count_with_a_usage_line(launcher, tmp_path):
    assert launcher.name in LAUNCHER_BAD_ARGUMENTS_MAP

    if LAUNCHER_BAD_ARGUMENTS_MAP[launcher.name] is None:
        pytest.skip(f"{launcher.name} takes any argument")

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


# --------------------------------------------------------------------------------

@pytest.mark.parametrize("launcher", LAUNCHER_LIST, ids=[file.name for file in LAUNCHER_LIST])
def test_a_launcher_is_two_lines_that_run_one_module_through_uv_without_the_project(launcher):
    line_list = launcher.read_text(encoding="utf-8").splitlines()

    assert len(line_list) == 2
    assert line_list[0] == _LAUNCHER_SHEBANG
    assert line_list[1].startswith("exec uv run --directory ")
    assert " --no-project " in line_list[1] or " --isolated --frozen " in line_list[1]
    assert line_list[1].endswith(' "$@"')


# --------------------------------------------------------------------------------

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


# --------------------------------------------------------------------------------

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


# --------------------------------------------------------------------------------

def test_the_build_launcher_refuses_a_tag_other_than_local_or_test_from_another_directory(tmp_path):
    environ = _launcher_environ(tmp_path / "config1")
    environ["SBX_IMAGE_TAG"] = "latest"

    result = subprocess.run(
        [str(REPO_DIR / "build.sh")],
        cwd=tmp_path,
        env=environ,
        stdin=subprocess.DEVNULL,
        capture_output=True,
        text=True,
        check=False,
    )

    assert result.returncode == 1
    assert result.stdout == ""
    assert result.stderr == "build.sh: SBX_IMAGE_TAG must be local or test, not 'latest'\n"


# --------------------------------------------------------------------------------
# Every command refuses another image tag before it does anything
# --------------------------------------------------------------------------------
# The main of each command runs in process with the recorder and an unknown tag.
# Each must exit 1 with the tag text, reach no Docker, read no registry entry
# and make no file or directory.
# --------------------------------------------------------------------------------

def _run_add(environ, recorder, work_dir):
    return add_module.main(["name1", str(work_dir / "new dir" / "one")], environ)


# --------------------------------------------------------------------------------

def _run_list(environ, recorder, work_dir):
    return list_module.main([], environ, docker=recorder)


# --------------------------------------------------------------------------------

def _run_start(environ, recorder, work_dir):
    return start_module.main(["name1"], environ, docker=recorder)


# --------------------------------------------------------------------------------

def _run_stop(environ, recorder, work_dir):
    return stop_module.main(["name1"], environ, docker=recorder)


# --------------------------------------------------------------------------------

def _run_shell(environ, recorder, work_dir):
    return shell_module.main(["name1"], environ, docker=recorder, exec_function=_refuse_exec)


# --------------------------------------------------------------------------------

def _run_upgrade(environ, recorder, work_dir):
    return upgrade_module.main(["name1"], environ, docker=recorder, build_function=_refuse_build)


# --------------------------------------------------------------------------------

def _run_rm(environ, recorder, work_dir):
    return rm_module.main(["name1"], environ, docker=recorder)


# --------------------------------------------------------------------------------

def _run_fix_modes(environ, recorder, work_dir):
    return fix_modes_module.main(["name1"], environ)


# --------------------------------------------------------------------------------

def _run_build(environ, recorder, work_dir):
    return build_module.main([], environ, docker=recorder)


# --------------------------------------------------------------------------------

def _refuse_exec(file, argument_list, environ):
    raise AssertionError("exec was called")


# --------------------------------------------------------------------------------

def _refuse_build(option_list, environ, docker, repo_dir):
    raise AssertionError("the build was called")


TAG_COMMAND_MAP = {
    "sbx-add": _run_add,
    "sbx-list": _run_list,
    "sbx-start": _run_start,
    "sbx-stop": _run_stop,
    "sbx-shell": _run_shell,
    "sbx-upgrade": _run_upgrade,
    "sbx-rm": _run_rm,
    "sbx-fix-modes": _run_fix_modes,
    "build.sh": _run_build,
}


def _tree_snapshot(root: Path) -> list[str]:
    path_list = []

    for path in root.rglob("*"):
        path_list.append(str(path))

    return sorted(path_list)


# --------------------------------------------------------------------------------

@pytest.mark.parametrize("command_name", list(TAG_COMMAND_MAP))
def test_every_command_refuses_the_latest_tag_before_it_reads_the_registry_or_calls_docker(
    command_name, tmp_path, capsys
):
    recorder = DockerRecorder()
    work_dir = tmp_path / "work"
    work_dir.mkdir()
    environ = {"SBX_CONFIG_DIR": str(work_dir / "config1"), "SBX_IMAGE_TAG": "latest", "PATH": os.environ["PATH"]}
    before = _tree_snapshot(tmp_path)

    exit_code = TAG_COMMAND_MAP[command_name](environ, recorder, work_dir)
    captured = capsys.readouterr()

    assert exit_code == 1
    assert captured.out == ""
    assert captured.err == f"{command_name}: SBX_IMAGE_TAG must be local or test, not 'latest'\n"
    assert recorder.call_list == []
    assert _tree_snapshot(tmp_path) == before


# --------------------------------------------------------------------------------

def test_the_tag_map_holds_every_command_the_launchers_run():
    no_tag_command_list = ["sbx-migrate-registry", "clean.sh", "host-test.sh"]
    expected_name_list = []

    for name in LAUNCHER_BAD_ARGUMENTS_MAP:
        if name not in no_tag_command_list:
            expected_name_list.append(name)

    assert sorted(TAG_COMMAND_MAP) == sorted(expected_name_list)
