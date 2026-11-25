# --------------------------------------------------------------------------------
# Tests of clean.sh as the sbx.clean module
# --------------------------------------------------------------------------------
# Real directories under tmp_path stand for the temp base. Docker is a recorder
# that also answers which directory each test container mounts, so nothing here
# needs Docker and nothing is removed outside tmp_path.
# --------------------------------------------------------------------------------

import os

import pytest

from sbx import clean as clean_module
from sbx.docker import DockerResult
from sbx_helpers import DockerRecorder

DRY_RUN_TEXT = "Dry run: nothing removed. Run ./clean.sh --yes to clean up.\n"
USAGE_TEXT = "Usage: clean.sh [--yes]\n"
ROOT_CA_TITLE = "=== Test root certificate directories\n"
RUN_DIR_TITLE = "=== Host-test run directories\n"


# --------------------------------------------------------------------------------
# Fixtures and helpers
# --------------------------------------------------------------------------------

class MountRecorder(DockerRecorder):
    # A recorder that answers the inspect of each container with the directory
    # it is told that container mounts; a container it is not told about is gone.
    def __init__(self) -> None:
        super().__init__()
        self.mount_by_name_map: dict[str, str] = {}

    def __call__(self, argument_list, environ=None, capture=True):
        result = super().__call__(argument_list, environ, capture)

        if argument_list[:2] != ["container", "inspect"]:
            return result

        name = argument_list[-1]

        if name not in self.mount_by_name_map:
            return DockerResult(1, "")

        return DockerResult(0, self.mount_by_name_map[name] + "\n")


@pytest.fixture
def temp_base(tmp_path):
    base1 = tmp_path / "temp1"
    base1.mkdir()

    return base1


@pytest.fixture
def mount_recorder():
    return MountRecorder()


@pytest.fixture
def run_clean(temp_base, mount_recorder, capsys):
    def run(argument_list, docker=None):
        environ = {"TMPDIR": f"{temp_base}/"}
        exit_code = clean_module.main(argument_list, environ, docker=docker or mount_recorder)
        captured = capsys.readouterr()

        return exit_code, captured.out, captured.err

    return run


def _make_dir(path):
    path.mkdir(parents=True)
    (path / "file1.txt").write_text("x", encoding="utf-8")

    return path


def _plan_test_containers(temp_base, mount_recorder):
    run_dir1 = _make_dir(temp_base / "sbx-hosttest-20261119-101010.abc" / "claude sandbox")
    run_dir2 = _make_dir(temp_base / "sbx-hosttest-20261119-101010.abc" / "cursor sandbox")
    mount_recorder.mount_by_name_map = {
        "sbx-hosttest-claude": str(run_dir1),
        "sbx-hosttest-cursor": str(run_dir2),
        "sbx-hosttest-mine": "/Users/x/work",
        "sbx-hosttest": str(run_dir1),
    }
    mount_recorder.answer(
        ["ps", "-a", "--format", "{{.Names}}"],
        DockerResult(0, "sbx-hosttest-claude\nsbx-hosttest-cursor\nsbx-hosttest-mine\nsbx-hosttest\nsbx-sbx1\nhosttest\n"),
    )


# --------------------------------------------------------------------------------
# The verdict on one test container
# --------------------------------------------------------------------------------

def test_a_test_container_that_mounts_a_run_directory_is_removed(temp_base):
    source = f"{temp_base}/sbx-hosttest-20261119-101010.abc/claude sandbox"

    assert clean_module.hosttest_container_verdict("sbx-hosttest-claude", source, temp_base) == "remove"


def test_the_same_name_mounting_a_directory_of_yours_is_kept(temp_base):
    assert clean_module.hosttest_container_verdict("sbx-hosttest-claude", "/Users/x/work", temp_base) == "keep"


def test_the_old_single_test_container_mounting_a_run_directory_is_removed(temp_base):
    source = f"{temp_base}/sbx-hosttest-20261119-1.x"

    assert clean_module.hosttest_container_verdict("sbx-hosttest", source, temp_base) == "remove"


def test_no_container_is_absent(temp_base):
    assert clean_module.hosttest_container_verdict("sbx-hosttest-claude", None, temp_base) == "absent"


def test_a_container_with_no_workspace_mount_is_kept(temp_base):
    assert clean_module.hosttest_container_verdict("sbx-hosttest-claude", "", temp_base) == "keep"


def test_a_mount_in_a_certificate_directory_is_kept(temp_base):
    for name in ["sbx-test-root-ca", "sbx-hosttest-root-ca"]:
        source = f"{temp_base}/{name}/inner"

        assert clean_module.hosttest_container_verdict("sbx-hosttest-claude", source, temp_base) == "keep"


def test_a_mount_outside_the_temp_base_that_names_a_run_directory_is_kept(temp_base):
    source = "/Users/x/sbx-hosttest-20261119-1.x"

    assert clean_module.hosttest_container_verdict("sbx-hosttest-claude", source, temp_base) == "keep"


def test_a_resolved_temp_base_with_a_private_prefix_still_matches(tmp_path):
    real_base = tmp_path / "real1"
    real_base.mkdir()
    link_base = tmp_path / "link1"
    link_base.symlink_to(real_base)
    source = f"{real_base}/sbx-hosttest-20261119-1.x/claude sandbox"

    assert clean_module.hosttest_container_verdict("sbx-hosttest-claude", source, link_base) == "remove"


# --------------------------------------------------------------------------------
# The directory lists
# --------------------------------------------------------------------------------

def test_run_dir_list_holds_only_the_run_directories(temp_base):
    run_dir1 = _make_dir(temp_base / "sbx-hosttest-20261119-1.x")
    _make_dir(temp_base / "sbx-hosttest-root-ca")
    _make_dir(temp_base / "sbx-test-root-ca")
    _make_dir(temp_base / "other")
    (temp_base / "sbx-hosttest-file1").write_text("x", encoding="utf-8")

    assert clean_module.run_dir_list(temp_base) == [run_dir1]


def test_root_ca_dir_list_names_the_two_certificate_directories(temp_base):
    _make_dir(temp_base / "sbx-hosttest-20261119-1.x")
    old_dir1 = _make_dir(temp_base / "sbx-hosttest-root-ca")
    new_dir1 = _make_dir(temp_base / "sbx-test-root-ca")
    _make_dir(temp_base / "other")

    assert clean_module.root_ca_dir_list(temp_base) == [new_dir1, old_dir1]


def test_both_lists_are_empty_for_an_empty_temp_base(temp_base):
    assert clean_module.run_dir_list(temp_base) == []
    assert clean_module.root_ca_dir_list(temp_base) == []


# --------------------------------------------------------------------------------
# A dry run
# --------------------------------------------------------------------------------

def test_without_arguments_it_only_shows_and_removes_nothing(temp_base, mount_recorder, run_clean):
    _plan_test_containers(temp_base, mount_recorder)
    _make_dir(temp_base / "sbx-test-root-ca")

    exit_code, out, err = run_clean([])

    assert exit_code == 0
    assert err == ""
    assert out.endswith(DRY_RUN_TEXT)
    assert "sbx-hosttest-claude mounts a host-test run directory: --yes removes it" in out
    assert "sbx-hosttest-mine does not mount a host-test run directory: --yes keeps it" in out
    assert (temp_base / "sbx-hosttest-20261119-101010.abc" / "claude sandbox" / "file1.txt").is_file()
    assert (temp_base / "sbx-test-root-ca" / "file1.txt").is_file()

    for call in mount_recorder.call_list:
        assert call[0] not in ("rm", "network", "builder")
        assert "prune" not in call



def test_the_certificate_directories_have_their_own_section(temp_base, mount_recorder, run_clean):
    run_dir1 = _make_dir(temp_base / "sbx-hosttest-20261119-1.x")
    root_dir1 = _make_dir(temp_base / "sbx-test-root-ca")
    old_dir1 = _make_dir(temp_base / "sbx-hosttest-root-ca")

    exit_code, out, err = run_clean([])

    run_section, root_section = out.split(ROOT_CA_TITLE)
    run_section = run_section.split(RUN_DIR_TITLE)[1]

    assert exit_code == 0
    assert str(run_dir1) in run_section
    assert str(root_dir1) not in run_section
    assert str(old_dir1) not in run_section
    assert str(root_dir1) in root_section
    assert str(old_dir1) in root_section


# --------------------------------------------------------------------------------
# --yes
# --------------------------------------------------------------------------------

def test_yes_removes_the_test_containers_their_networks_and_the_directories(temp_base, mount_recorder, run_clean):
    _plan_test_containers(temp_base, mount_recorder)
    _make_dir(temp_base / "sbx-test-root-ca")
    _make_dir(temp_base / "sbx-hosttest-root-ca")
    other_dir1 = _make_dir(temp_base / "other")

    exit_code, out, err = run_clean(["--yes"])
    call_list = mount_recorder.call_list

    assert exit_code == 0
    assert err == ""
    assert ["rm", "-f", "sbx-hosttest-claude"] in call_list
    assert ["rm", "-f", "sbx-hosttest-cursor"] in call_list
    assert ["rm", "-f", "sbx-hosttest"] in call_list
    assert ["network", "rm", "sbx-hosttest-claude_default"] in call_list
    assert ["network", "rm", "sbx-hosttest-cursor_default"] in call_list
    assert ["network", "rm", "sbx-hosttest_default"] in call_list
    assert ["rm", "-f", "sbx-hosttest-mine"] not in call_list
    assert ["rm", "-f", "sbx-sbx1"] not in call_list
    assert ["rm", "-f", "hosttest"] not in call_list
    assert "sbx-hosttest-mine does not mount a host-test run directory; left alone, with its network" in out
    assert list(temp_base.glob("sbx-*")) == []
    assert other_dir1.is_dir()


def test_yes_prunes_the_build_cache_then_the_images_after_the_removals(temp_base, mount_recorder, run_clean):
    _plan_test_containers(temp_base, mount_recorder)

    exit_code, out, err = run_clean(["--yes"])
    call_list = mount_recorder.call_list
    builder_index = call_list.index(["builder", "prune", "-a", "-f"])
    image_index = call_list.index(["image", "prune", "-a", "-f"])

    assert exit_code == 0
    assert builder_index < image_index
    assert call_list.index(["rm", "-f", "sbx-hosttest-claude"]) < builder_index
    assert call_list[-1] == ["system", "df"]
    assert out.endswith("=== Docker disk use after\n")


def test_a_missing_network_is_said_and_is_not_an_error(temp_base, mount_recorder, run_clean):
    _plan_test_containers(temp_base, mount_recorder)
    mount_recorder.answer(["network", "rm"], DockerResult(1, ""))

    exit_code, out, err = run_clean(["--yes"])

    assert exit_code == 0
    assert "(no sbx-hosttest-claude_default network)" in out


def test_a_container_that_cannot_be_removed_stops_the_run_before_any_directory_goes(
    temp_base, mount_recorder, run_clean
):
    _plan_test_containers(temp_base, mount_recorder)
    mount_recorder.answer(["rm", "-f", "sbx-hosttest-claude"], DockerResult(1, ""))

    exit_code, out, err = run_clean(["--yes"])

    assert exit_code == 1
    assert err == "clean.sh: docker rm -f sbx-hosttest-claude failed; no directory was removed\n"
    assert (temp_base / "sbx-hosttest-20261119-101010.abc" / "claude sandbox" / "file1.txt").is_file()
    assert ["image", "prune", "-a", "-f"] not in mount_recorder.call_list


@pytest.mark.skipif(os.geteuid() == 0, reason="root can remove a directory whose parent is read-only")
def test_a_directory_that_cannot_be_removed_is_reported_and_the_rest_goes_on(temp_base, mount_recorder, run_clean):
    run_dir1 = _make_dir(temp_base / "sbx-hosttest-20261119-1.x")
    locked_dir1 = _make_dir(run_dir1 / "locked1")
    run_dir2 = _make_dir(temp_base / "sbx-hosttest-20261119-2.x")
    locked_dir1.chmod(0o500)

    try:
        exit_code, out, err = run_clean(["--yes"])
    finally:
        locked_dir1.chmod(0o700)

    assert exit_code == 1
    assert f"clean.sh: could not remove {run_dir1}: " in err
    assert err.endswith("clean.sh: some directories could not be removed; the messages above name them\n")
    assert run_dir1.is_dir()
    assert not run_dir2.exists()
    assert ["image", "prune", "-a", "-f"] in mount_recorder.call_list


# --------------------------------------------------------------------------------
# Refusals
# --------------------------------------------------------------------------------

def test_an_unknown_option_is_the_usage_and_touches_nothing(temp_base, mount_recorder, run_clean):
    _make_dir(temp_base / "sbx-hosttest-20261119-1.x")

    exit_code, out, err = run_clean(["--bogus"])

    assert exit_code == 2
    assert out == ""
    assert err == USAGE_TEXT
    assert mount_recorder.call_list == []
    assert (temp_base / "sbx-hosttest-20261119-1.x" / "file1.txt").is_file()


def test_two_arguments_are_the_usage(mount_recorder, run_clean):
    exit_code, out, err = run_clean(["--yes", "--yes"])

    assert exit_code == 2
    assert err == USAGE_TEXT
    assert mount_recorder.call_list == []


def test_without_docker_nothing_is_removed(temp_base, mount_recorder, run_clean):
    _make_dir(temp_base / "sbx-hosttest-20261119-1.x")
    mount_recorder.answer(["info"], DockerResult(1, ""))

    exit_code, out, err = run_clean(["--yes"])

    assert exit_code == 1
    assert err == "clean.sh: cannot reach Docker; is Docker running?\n"
    assert mount_recorder.call_list == [["info"]]
    assert (temp_base / "sbx-hosttest-20261119-1.x" / "file1.txt").is_file()


def test_a_failed_docker_ps_removes_nothing(temp_base, mount_recorder, run_clean):
    _make_dir(temp_base / "sbx-hosttest-20261119-1.x")
    mount_recorder.answer(["ps"], DockerResult(1, ""))

    exit_code, out, err = run_clean(["--yes"])

    assert exit_code == 1
    assert err == "clean.sh: docker ps failed; nothing was removed\n"
    assert (temp_base / "sbx-hosttest-20261119-1.x" / "file1.txt").is_file()
