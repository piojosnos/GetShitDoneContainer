# ------------------------------------------------------------------------------
# Tests of the sbx-selfcheck primitives
# ------------------------------------------------------------------------------
# Pin and command readers, the tool result and the root-owned and protected path
# results. Real binaries; a stand-in executable where output must vary.
# ------------------------------------------------------------------------------

import os
import platform
import shutil
import sys
from pathlib import Path

import pytest

import selfcheck_core
from helpers import TEMURIN_PIN1, environment_with, write_stand_in
from helpers import TEMURIN_PIN1, environment_with, write_stand_in

ROOT_MOUNT_LINE = "1 0 8:1 / / rw - ext4 /dev/sda1 rw"
MOUNT_LINE_TEMPLATE = "{number} 1 8:2 / {mount_point} rw,noatime - ext4 /dev/sda2 rw"


def write_mountinfo(mountinfo_file: Path, mount_point_list: list[str]) -> None:
    line_list = [ROOT_MOUNT_LINE]

    for index, mount_point in enumerate(mount_point_list):
        line_list.append(MOUNT_LINE_TEMPLATE.format(number=index + 2, mount_point=mount_point))

    mountinfo_file.write_text("\n".join(line_list) + "\n")


def write_file(path: Path, text: str = "text1") -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(text)


# ------------------------------------------------------------------------------
# Mount, pin and command readers
# ------------------------------------------------------------------------------

def test_mount_point_set_reads_the_fifth_field_of_each_line():
    text = ROOT_MOUNT_LINE + "\n" + MOUNT_LINE_TEMPLATE.format(number=2, mount_point="/mount1") + "\n"

    assert selfcheck_core.mount_point_set(text) == {"/", "/mount1"}


def test_mount_point_set_ignores_blank_and_short_lines():
    assert selfcheck_core.mount_point_set("\n1 0 8:1\n" + ROOT_MOUNT_LINE + "\n") == {"/"}


def test_parse_versions_text_skips_comments_and_blank_lines_and_splits_once():
    text = "# comment1\n\nNAME1=a=b\n  NAME2 = value2 \nbroken line\n"

    assert selfcheck_core.parse_versions_text(text) == {"NAME1": "a=b", "NAME2": "value2"}


def test_pin_value_reads_a_name_from_the_file(tmp_path):
    versions1 = tmp_path / "versions1"
    versions1.write_text("# comment1\n\nNAME1=a=b\nNAME2=c\n")

    assert selfcheck_core.pin_value("NAME1", versions1) == "a=b"


def test_pin_value_is_empty_for_a_missing_name_or_file(tmp_path):
    versions1 = tmp_path / "versions1"
    versions1.write_text("NAME1=a\n")

    assert selfcheck_core.pin_value("NAME2", versions1) == ""
    assert selfcheck_core.pin_value("NAME1", tmp_path / "missing1") == ""


def test_missing_pin_result_fails_with_the_mac_rebuild_command():
    result = selfcheck_core.missing_pin_result("NAME1")

    assert not result.passed
    assert "NAME1" in result.detail
    assert result.hint == selfcheck_core.rebuild_hint()


def test_run_command_captures_text_output_and_closes_stdin():
    completed = selfcheck_core.run_command(["cat"])

    assert completed.returncode == 0
    assert completed.stdout == ""


def test_run_command_passes_the_given_environment():
    completed = selfcheck_core.run_command(["env"], {"NAME1": "value1"})

    assert completed.stdout.strip() == "NAME1=value1"


# ------------------------------------------------------------------------------
# Root-owned and protected path results
# ------------------------------------------------------------------------------

def test_root_owned_passes_on_the_real_root_files():
    result = selfcheck_core.root_owned_result([("/etc/passwd", 0o644), ("/etc", 0o755)])

    assert result.passed
    assert "2 paths" in result.detail


def test_root_owned_fails_naming_uid_gid_and_mode_of_a_file_made_by_the_test_user(tmp_path):
    write_file(tmp_path / "path1")
    (tmp_path / "path1").chmod(0o644)

    result = selfcheck_core.root_owned_result([(str(tmp_path / "path1"), 0o644)])

    assert not result.passed
    assert f"{tmp_path / 'path1'} is {os.getuid()}:{os.getgid()} 644, expected root:root 644" in result.detail
    assert "on the Mac run: sbx-upgrade" in result.hint


def test_root_owned_fails_for_a_missing_path(tmp_path):
    result = selfcheck_core.root_owned_result([(str(tmp_path / "path1"), 0o644)])

    assert not result.passed
    assert "path1 is missing" in result.detail


@pytest.mark.skipif(os.getuid() == 0, reason="root can write everywhere")
def test_protected_paths_fail_for_a_writable_file_and_pass_after_chmod(tmp_path, restorable_mode):
    folder1 = tmp_path / "folder1"
    write_file(folder1 / "sub1" / "file1")
    mountinfo1 = tmp_path / "mountinfo1"
    write_mountinfo(mountinfo1, [])

    writable_result = selfcheck_core.protected_paths_result([folder1], mountinfo1)

    assert not writable_result.passed
    assert str(folder1 / "sub1" / "file1") in writable_result.detail

    restorable_mode(folder1 / "sub1" / "file1", 0o444)
    restorable_mode(folder1 / "sub1", 0o555)
    restorable_mode(folder1, 0o555)

    assert selfcheck_core.protected_paths_result([folder1], mountinfo1).passed


@pytest.mark.skipif(os.getuid() == 0, reason="root can write everywhere")
def test_protected_paths_fail_for_a_mount_below_the_folder(tmp_path, restorable_mode):
    folder1 = tmp_path / "folder1"
    write_file(folder1 / "sub1" / "file1")
    restorable_mode(folder1 / "sub1" / "file1", 0o444)
    restorable_mode(folder1 / "sub1", 0o555)
    restorable_mode(folder1, 0o555)
    mountinfo1 = tmp_path / "mountinfo1"
    write_mountinfo(mountinfo1, [str(folder1 / "sub1")])

    result = selfcheck_core.protected_paths_result([folder1], mountinfo1)

    assert not result.passed
    assert f"{folder1 / 'sub1'} is a mount point" in result.detail


@pytest.mark.skipif(os.getuid() == 0, reason="root can write everywhere")
def test_protected_paths_ignore_a_mount_beside_the_folder(tmp_path, restorable_mode):
    folder1 = tmp_path / "folder1"
    write_file(folder1 / "file1")
    restorable_mode(folder1 / "file1", 0o444)
    restorable_mode(folder1, 0o555)
    mountinfo1 = tmp_path / "mountinfo1"
    write_mountinfo(mountinfo1, [str(tmp_path / "folder10")])

    assert selfcheck_core.protected_paths_result([folder1], mountinfo1).passed


def test_protected_paths_fail_for_a_missing_path(tmp_path):
    mountinfo1 = tmp_path / "mountinfo1"
    write_mountinfo(mountinfo1, [])

    result = selfcheck_core.protected_paths_result([tmp_path / "folder1"], mountinfo1)

    assert not result.passed
    assert "folder1 is missing" in result.detail


@pytest.mark.skipif(os.getuid() == 0, reason="root can write everywhere")
def test_protected_paths_name_at_most_ten_entries_and_the_total(tmp_path):
    folder1 = tmp_path / "folder1"

    for number in range(13):
        write_file(folder1 / f"file{number:02d}")

    mountinfo1 = tmp_path / "mountinfo1"
    write_mountinfo(mountinfo1, [])

    result = selfcheck_core.protected_paths_result([folder1], mountinfo1)

    assert not result.passed
    assert "14 problems" in result.detail
    assert result.detail.count(" is writable") == 10


def test_protected_paths_do_not_follow_a_link_while_walking(tmp_path):
    folder1 = tmp_path / "folder1"
    outside1 = tmp_path / "outside1"
    folder1.mkdir()
    write_file(outside1 / "file1")
    (folder1 / "link1").symlink_to(outside1)
    mountinfo1 = tmp_path / "mountinfo1"
    write_mountinfo(mountinfo1, [])

    result = selfcheck_core.protected_paths_result([folder1], mountinfo1)

    assert "link1/file1" not in result.detail


# ------------------------------------------------------------------------------
# Version, ELF and tool results
# ------------------------------------------------------------------------------

CURRENT_PYTHON_TEXT = f"Python {platform.python_version()}"


def test_version_matches_accepts_equal_text_and_text_followed_by_a_space():
    assert selfcheck_core.version_matches("uv 0.12.21", "uv 0.12.21")
    assert selfcheck_core.version_matches("uv 0.12.21 (abc 2026-01-01)", "uv 0.12.21")


def test_version_matches_rejects_a_longer_or_shorter_version():
    assert not selfcheck_core.version_matches("uv 0.12.210", "uv 0.12.21")
    assert not selfcheck_core.version_matches("uv 0.12.2", "uv 0.12.21")


def test_is_under_accepts_the_root_itself_and_what_sits_below_it():
    assert selfcheck_core.is_under("/home/sandbox/x", "/home")
    assert selfcheck_core.is_under("/home", "/home")


def test_is_under_rejects_a_sibling_that_shares_the_prefix_and_other_roots():
    assert not selfcheck_core.is_under("/homeowner/x", "/home")
    assert not selfcheck_core.is_under("/usr/bin/git", "/home")


def test_image_tag_takes_the_text_after_the_last_colon_before_the_digest():
    assert selfcheck_core.image_tag("ghcr.io/astral-sh/uv:0.12.21@sha256:abc") == "0.12.21"
    assert selfcheck_core.image_tag(TEMURIN_PIN1) == "21.0.12_8-jdk-noble"
    assert selfcheck_core.image_tag("registry1:5000/image1:1.2@sha256:abc") == "1.2"


def test_jdk_version_is_the_tag_up_to_its_first_underscore():
    assert selfcheck_core.jdk_version(TEMURIN_PIN1) == "21.0.12"


def test_elf_machine_of_the_running_interpreter_is_the_machine_of_the_container():
    interpreter = Path(os.path.realpath(sys.executable))

    assert selfcheck_core.elf_machine(interpreter) == selfcheck_core.ELF_MACHINE_BY_UNAME_MAP[platform.machine()]


def test_elf_machine_of_a_text_file_is_none(tmp_path):
    text_file = tmp_path / "text1.txt"
    text_file.write_text("not a binary, but longer than twenty bytes\n")

    assert selfcheck_core.elf_machine(text_file) is None


def test_elf_machine_of_a_file_shorter_than_the_header_is_none(tmp_path):
    short_file = tmp_path / "short1"
    short_file.write_bytes(b"\x7fELF")

    assert selfcheck_core.elf_machine(short_file) is None


def test_first_output_line_takes_stdout_then_stderr(bin1):
    write_stand_in(bin1, "tool1", 'echo; echo "out1"; echo "err1" >&2')
    write_stand_in(bin1, "tool2", 'echo "err2" >&2')
    environment1 = environment_with(bin1)

    assert selfcheck_core.first_output_line(selfcheck_core.run_command(["tool1"], environment1)) == "out1"
    assert selfcheck_core.first_output_line(selfcheck_core.run_command(["tool2"], environment1)) == "err2"


def test_tool_result_passes_when_the_line_starts_with_the_pin_and_a_space(bin1):
    write_stand_in(bin1, "tool1", 'echo "tool1 1.2.3 (build1)"')

    result = selfcheck_core.tool_result("tool1", ["--version"], "tool1 1.2.3", environment_map=environment_with(bin1))

    assert result.passed
    assert str(bin1 / "tool1") in result.detail
    assert "tool1 1.2.3 (build1)" in result.detail


def test_tool_result_fails_for_a_longer_version_with_the_rebuild_command(bin1):
    write_stand_in(bin1, "tool1", 'echo "tool1 1.2.30"')

    result = selfcheck_core.tool_result("tool1", ["--version"], "tool1 1.2.3", environment_map=environment_with(bin1))

    assert not result.passed
    assert "tool1 reports 'tool1 1.2.30'; the pin is 'tool1 1.2.3'" in result.detail
    assert "sbx-upgrade" in result.hint


def test_tool_result_fails_when_the_version_command_exits_non_zero(bin1):
    write_stand_in(bin1, "tool1", 'echo "tool1 1.2.3"; exit 1')

    result = selfcheck_core.tool_result("tool1", ["--version"], "tool1 1.2.3", environment_map=environment_with(bin1))

    assert not result.passed
    assert "the pin is" in result.detail


def test_tool_result_fails_when_the_required_text_is_missing(bin1):
    write_stand_in(bin1, "tool1", 'echo "tool1 1.2.3 (build1)"')

    result = selfcheck_core.tool_result(
        "tool1", ["--version"], "tool1 1.2.3", required_text="vendor1", environment_map=environment_with(bin1)
    )

    assert not result.passed
    assert "tool1 output lacks 'vendor1'" in result.detail


def test_tool_result_passes_when_the_required_text_is_on_stderr(bin1):
    write_stand_in(bin1, "tool1", 'echo "tool1 1.2.3"; echo "vendor1" >&2')

    result = selfcheck_core.tool_result(
        "tool1", ["--version"], "tool1 1.2.3", required_text="vendor1", environment_map=environment_with(bin1)
    )

    assert result.passed


def test_tool_result_fails_for_a_command_that_is_not_on_the_path(bin1):
    result = selfcheck_core.tool_result("missing1", environment_map={"PATH": str(bin1)})

    assert not result.passed
    assert result.detail == "missing1 is not on PATH"
    assert "sbx-upgrade" in result.hint


def test_tool_result_fails_when_the_tool_resolves_under_the_forbidden_root(bin1):
    write_stand_in(bin1, "tool1", 'echo "tool1 1.2.3"')

    result = selfcheck_core.tool_result("tool1", environment_map=environment_with(bin1), home_root=str(bin1.parent))

    assert not result.passed
    assert f"tool1 resolves to {bin1 / 'tool1'}, under {bin1.parent}, not the image" in result.detail
    assert "remove it" in result.hint


def test_tool_result_follows_a_link_to_the_real_file_before_judging_the_folder(tmp_path, bin1):
    real_dir = tmp_path / "real1"
    real_dir.mkdir()
    write_stand_in(real_dir, "tool1", 'echo "tool1 1.2.3"')
    (bin1 / "tool1").symlink_to(real_dir / "tool1")

    result = selfcheck_core.tool_result("tool1", environment_map=environment_with(bin1), home_root=str(real_dir))

    assert not result.passed
    assert str(real_dir / "tool1") in result.detail


def test_tool_result_fails_for_a_binary_of_another_machine(bin1):
    other_machine_header = b"\x7fELF" + bytes(14) + (0x28).to_bytes(2, "little") + bytes(8)
    (bin1 / "tool1").write_bytes(other_machine_header)
    (bin1 / "tool1").chmod(0o755)

    result = selfcheck_core.tool_result("tool1", environment_map=environment_with(bin1))

    assert not result.passed
    assert f"tool1 is built for ELF machine 0x28, not {platform.machine()}" in result.detail
    assert "sbx-upgrade" in result.hint


def test_tool_result_passes_for_the_python_that_runs_the_checks():
    result = selfcheck_core.tool_result("python3", ["--version"], CURRENT_PYTHON_TEXT)

    assert result.passed
    assert os.path.realpath(shutil.which("python3")) in result.detail


def test_tool_result_without_a_version_command_passes_with_the_resolved_path_only():
    result = selfcheck_core.tool_result("git")

    assert result.passed
    assert result.detail == os.path.realpath(shutil.which("git"))


# ------------------------------------------------------------------------------
# Expected base versions text
# ------------------------------------------------------------------------------

BASE_VERSIONS_TEXT1 = "gsd 1.15.0 | node 24.21.0 | jdk 21.0.12 | mvn 3.9.11 | python 3.12.3"


def test_expected_base_versions_text_is_built_from_the_pins_and_the_python_version(versions1):
    assert selfcheck_core.expected_base_versions_text(versions1, "3.12.3") == BASE_VERSIONS_TEXT1


def test_expected_base_versions_text_uses_the_running_python_by_default(versions1):
    text = selfcheck_core.expected_base_versions_text(versions1)

    assert text.endswith(f"| python {platform.python_version()}")


def test_expected_base_versions_text_names_the_missing_pin(tmp_path, versions1):
    versions2 = tmp_path / "versions2.env"
    versions2.write_text(versions1.read_text().replace("MAVEN_VERSION=3.9.11\n", ""))

    with pytest.raises(KeyError, match="MAVEN_VERSION"):
        selfcheck_core.expected_base_versions_text(versions2, "3.12.3")
