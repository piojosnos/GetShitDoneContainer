# --------------------------------------------------------------------------------
# Tests of sbx-fix-modes
# --------------------------------------------------------------------------------
# A real git repository under tmp_path and real file modes. The extended attribute
# is a stand-in function passed as a parameter: it keeps each attribute in a
# dictionary and, like macOS, refuses to write one on a read-only file.
# --------------------------------------------------------------------------------

import os
import stat
import subprocess
from pathlib import Path

import pytest

from sbx import fix_modes as fix_modes_module
from sbx.fix_modes import XattrResult
from sbx_helpers import environ_for, write_json_entry

ATTRIBUTE_NAME = "user.containers.override_stat"
GIT_IDENTITY = ["-c", "user.name=test", "-c", "user.email=test@example.com"]


# --------------------------------------------------------------------------------
# Stand-ins and helpers
# --------------------------------------------------------------------------------

class XattrStandIn:
    def __init__(self) -> None:
        self.value_map: dict[str, str] = {}
        self.call_list: list[list[str]] = []

    def __call__(self, argument_list: list[str]) -> XattrResult:
        self.call_list.append(list(argument_list))

        if argument_list[0] == "-p":
            file = argument_list[2]

            if file not in self.value_map:
                return XattrResult(1, "")

            return XattrResult(0, self.value_map[file] + "\n")

        file = argument_list[3]

        if not os.access(file, os.W_OK):
            return XattrResult(1, "")

        self.value_map[file] = argument_list[2]

        return XattrResult(0, "")


def _git(repo: Path, *argument_list: str) -> None:
    subprocess.run(["git", "-C", str(repo), *GIT_IDENTITY, *argument_list], check=True, capture_output=True)


def _make_repo(repo: Path) -> None:
    repo.mkdir(parents=True)
    _git(repo, "init", "-q")
    (repo / "run.sh").write_text("echo run\n")
    (repo / "ro.sh").write_text("echo ro\n")
    (repo / "plain.sh").write_text("echo plain\n")
    (repo / "doc.md").write_text("doc\n")
    (repo / "sub dir").mkdir()
    (repo / "sub dir" / "a b.sh").write_text("echo ab\n")
    (repo / "link.sh").symlink_to("run.sh")
    (repo / "run.sh").chmod(0o755)
    (repo / "ro.sh").chmod(0o755)
    (repo / "plain.sh").chmod(0o755)
    (repo / "sub dir" / "a b.sh").chmod(0o755)
    (repo / "doc.md").chmod(0o644)
    _git(repo, "add", ".")
    _git(repo, "commit", "-q", "-m", "init")


def _drift(repo: Path, xattr: XattrStandIn) -> None:
    (repo / "run.sh").chmod(0o600)
    (repo / "doc.md").chmod(0o755)
    (repo / "ro.sh").chmod(0o444)
    (repo / "sub dir" / "a b.sh").chmod(0o644)
    xattr.value_map[str(repo / "run.sh")] = "1001:1001:0100644"
    xattr.value_map[str(repo / "ro.sh")] = "1001:1001:0100644"


def _mode_of(file: Path) -> int:
    return stat.S_IMODE(file.stat().st_mode)


@pytest.fixture
def project_dir(registry, tmp_path) -> Path:
    sandbox_dir = tmp_path / "modes dir"
    (sandbox_dir / "state").mkdir(parents=True)
    write_json_entry(registry, "fixed", str(sandbox_dir), "claude")
    repo = sandbox_dir / "fixed"
    _make_repo(repo)

    return repo


@pytest.fixture
def xattr() -> XattrStandIn:
    return XattrStandIn()


@pytest.fixture
def run_fix_modes(config_dir, capsys):
    def run(argument_list, xattr_function=None, extra_map=None):
        environ = environ_for(config_dir, extra_map)
        exit_code = fix_modes_module.main(argument_list, environ, xattr_function=xattr_function)
        captured = capsys.readouterr()

        return exit_code, captured.out, captured.err

    return run


# --------------------------------------------------------------------------------
# Refusals
# --------------------------------------------------------------------------------

@pytest.mark.parametrize("argument_list", [[], ["a", "b"]])
def test_a_wrong_argument_count_prints_the_usage(argument_list, run_fix_modes, xattr):
    exit_code, out, err = run_fix_modes(argument_list, xattr)

    assert exit_code == 2
    assert out == ""
    assert err == "Usage: sbx-fix-modes NAME\n"
    assert xattr.call_list == []


def test_an_unregistered_name_is_refused(run_fix_modes, xattr):
    exit_code, _, err = run_fix_modes(["nosuch"], xattr)

    assert exit_code == 1
    assert err == "sbx-fix-modes: nosuch is not registered; run: sbx-add nosuch HOST_PATH\n"


def test_a_name_that_breaks_the_rule_is_refused(run_fix_modes, xattr):
    exit_code, _, err = run_fix_modes(["../x"], xattr)

    assert exit_code == 1
    assert "breaks the sandbox name rule" in err


def test_a_project_directory_that_is_not_a_git_repository_is_refused(run_fix_modes, registry, tmp_path, xattr):
    sandbox_dir = tmp_path / "no git"
    (sandbox_dir / "nogit").mkdir(parents=True)
    write_json_entry(registry, "nogit", str(sandbox_dir), "claude")

    exit_code, _, err = run_fix_modes(["nogit"], xattr)

    assert exit_code == 1
    assert err == f"sbx-fix-modes: {sandbox_dir}/nogit is not the top directory of a git repository\n"
    assert xattr.call_list == []


def test_a_project_directory_below_the_top_of_a_repository_is_refused(run_fix_modes, registry, tmp_path, xattr):
    top = tmp_path / "top"
    _make_repo(top)
    (top / "inner").mkdir()
    write_json_entry(registry, "inner", str(top), "claude")

    exit_code, _, err = run_fix_modes(["inner"], xattr)

    assert exit_code == 1
    assert err == f"sbx-fix-modes: {top}/inner is not the top directory of a git repository\n"


# --------------------------------------------------------------------------------
# The host modes
# --------------------------------------------------------------------------------

def test_the_host_modes_follow_git_and_the_counts_line_is_printed(project_dir, run_fix_modes, xattr):
    _drift(project_dir, xattr)

    exit_code, out, err = run_fix_modes(["fixed"], xattr)

    assert exit_code == 0, err
    assert _mode_of(project_dir / "run.sh") == 0o755
    assert _mode_of(project_dir / "doc.md") == 0o644
    assert _mode_of(project_dir / "ro.sh") == 0o755
    assert _mode_of(project_dir / "sub dir" / "a b.sh") == 0o755
    assert _mode_of(project_dir / "plain.sh") == 0o755
    assert out == f"sbx-fix-modes: set 4 host modes and 2 sandbox modes from git in {project_dir}\n"


def test_a_symlink_and_an_untracked_file_are_skipped(project_dir, run_fix_modes, xattr):
    untracked = project_dir / "scratch.txt"
    untracked.write_text("scratch\n")
    untracked.chmod(0o600)
    run_target_mode = _mode_of(project_dir / "run.sh")
    xattr.value_map[str(untracked)] = "1001:1001:0100600"
    xattr.value_map[str(project_dir / "link.sh")] = "1001:1001:0100600"

    exit_code, out, _ = run_fix_modes(["fixed"], xattr)

    assert exit_code == 0
    assert _mode_of(untracked) == 0o600
    assert xattr.value_map[str(untracked)] == "1001:1001:0100600"
    assert xattr.value_map[str(project_dir / "link.sh")] == "1001:1001:0100600"
    assert _mode_of(project_dir / "run.sh") == run_target_mode
    assert "set 0 host modes and 0 sandbox modes" in out


def _add_index_entry(repo: Path, git_mode: str, relative_path: str) -> None:
    blob = subprocess.run(
        ["git", "-C", str(repo), "hash-object", "-w", "--stdin"],
        input=b"outside\n",
        check=True,
        capture_output=True,
    ).stdout.decode().strip()

    _git(repo, "update-index", "--add", "--cacheinfo", f"{git_mode},{blob},{relative_path}")


def test_a_file_reached_through_a_symlinked_directory_outside_the_project_is_left_alone(
    project_dir, run_fix_modes, xattr, tmp_path
):
    outside_dir = tmp_path / "outside"
    outside_dir.mkdir()
    outside_file = outside_dir / "key.sh"
    outside_file.write_text("outside\n")
    outside_file.chmod(0o600)
    xattr.value_map[str(outside_file)] = "1001:1001:0100600"
    (project_dir / "evil").symlink_to(outside_dir)
    _add_index_entry(project_dir, "100755", "evil/key.sh")

    exit_code, out, err = run_fix_modes(["fixed"], xattr)

    assert exit_code == 0, err
    assert _mode_of(outside_file) == 0o600
    assert xattr.value_map[str(outside_file)] == "1001:1001:0100600"
    assert not any(str(outside_file) in call or str(outside_dir) in call for call in xattr.call_list)
    assert f"sbx-fix-modes: skipped evil/key.sh; it resolves outside {project_dir}\n" in out


def test_a_file_reached_through_a_relative_symlink_to_a_parent_directory_is_left_alone(
    project_dir, run_fix_modes, xattr, tmp_path
):
    outside_file = tmp_path / "modes dir" / "state" / "token.sh"
    outside_file.write_text("outside\n")
    outside_file.chmod(0o600)
    (project_dir / "up").symlink_to("../state")
    _add_index_entry(project_dir, "100755", "up/token.sh")

    exit_code, out, err = run_fix_modes(["fixed"], xattr)

    assert exit_code == 0, err
    assert _mode_of(outside_file) == 0o600
    assert not any(str(outside_file) in call for call in xattr.call_list)
    assert "skipped up/token.sh" in out


def test_a_tracked_file_missing_from_the_work_tree_is_skipped(project_dir, run_fix_modes, xattr):
    (project_dir / "doc.md").unlink()

    exit_code, out, _ = run_fix_modes(["fixed"], xattr)

    assert exit_code == 0
    assert "set 0 host modes and 0 sandbox modes" in out


def test_a_second_run_changes_nothing(project_dir, run_fix_modes, xattr):
    _drift(project_dir, xattr)
    run_fix_modes(["fixed"], xattr)

    exit_code, out, _ = run_fix_modes(["fixed"], xattr)

    assert exit_code == 0
    assert out == f"sbx-fix-modes: set 0 host modes and 0 sandbox modes from git in {project_dir}\n"


# --------------------------------------------------------------------------------
# The sandbox mode, in the attribute
# --------------------------------------------------------------------------------

def test_the_attribute_takes_the_git_mode_and_keeps_the_owner(project_dir, run_fix_modes, xattr):
    xattr.value_map[str(project_dir / "run.sh")] = "501:20:0100644"

    exit_code, _, _ = run_fix_modes(["fixed"], xattr)

    assert exit_code == 0
    assert xattr.value_map[str(project_dir / "run.sh")] == "501:20:0100755"
    assert ["-w", ATTRIBUTE_NAME, "501:20:0100755", str(project_dir / "run.sh")] in xattr.call_list
    assert ["-p", ATTRIBUTE_NAME, str(project_dir / "run.sh")] in xattr.call_list


def test_a_644_file_gets_a_644_attribute(project_dir, run_fix_modes, xattr):
    xattr.value_map[str(project_dir / "doc.md")] = "1001:1001:0100755"

    run_fix_modes(["fixed"], xattr)

    assert xattr.value_map[str(project_dir / "doc.md")] == "1001:1001:0100644"


def test_a_file_without_the_attribute_gets_the_host_mode_only_and_no_attribute(project_dir, run_fix_modes, xattr):
    (project_dir / "plain.sh").chmod(0o644)

    exit_code, _, _ = run_fix_modes(["fixed"], xattr)

    assert exit_code == 0
    assert _mode_of(project_dir / "plain.sh") == 0o755
    assert str(project_dir / "plain.sh") not in xattr.value_map
    assert not any(call[0] == "-w" and call[-1] == str(project_dir / "plain.sh") for call in xattr.call_list)


def test_a_read_only_file_gets_its_host_mode_before_the_attribute_write(project_dir, run_fix_modes, xattr):
    (project_dir / "ro.sh").chmod(0o444)
    xattr.value_map[str(project_dir / "ro.sh")] = "1001:1001:0100644"

    exit_code, _, err = run_fix_modes(["fixed"], xattr)

    assert exit_code == 0, err
    assert xattr.value_map[str(project_dir / "ro.sh")] == "1001:1001:0100755"


def test_an_attribute_that_cannot_be_written_stops_the_run_with_the_file_named(project_dir, run_fix_modes):
    def refusing_xattr(argument_list: list[str]) -> XattrResult:
        if argument_list[0] == "-p":
            return XattrResult(0, "1:1:0100644\n")

        return XattrResult(1, "")

    exit_code, _, err = run_fix_modes(["fixed"], refusing_xattr)

    assert exit_code == 1
    assert err.startswith("sbx-fix-modes: xattr could not write the mode of ")


def test_without_xattr_the_host_modes_are_set_and_the_skip_is_said(project_dir, run_fix_modes, tmp_path):
    empty_dir = tmp_path / "empty-path"
    empty_dir.mkdir()
    (project_dir / "run.sh").chmod(0o600)

    exit_code, out, _ = run_fix_modes(["fixed"], None, {"PATH": str(empty_dir)})

    assert exit_code == 0
    assert _mode_of(project_dir / "run.sh") == 0o755
    assert out.splitlines() == [
        f"sbx-fix-modes: set 1 host modes and 0 sandbox modes from git in {project_dir}",
        "sbx-fix-modes: xattr is not installed, so the sandbox modes were not looked at",
    ]


def test_with_an_injected_xattr_function_the_skip_line_is_not_printed(project_dir, run_fix_modes, xattr):
    _, out, _ = run_fix_modes(["fixed"], xattr)

    assert "xattr is not installed" not in out
