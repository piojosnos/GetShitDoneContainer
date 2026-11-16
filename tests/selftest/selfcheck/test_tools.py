# ------------------------------------------------------------------------------
# Tests of the tool result
# ------------------------------------------------------------------------------
# Stand-in executables in tmp_path stand for the image's tools.
# ------------------------------------------------------------------------------

import os
import platform
import shutil

import tools
from helpers import environment_with, write_stand_in


# ------------------------------------------------------------------------------
# Constants and helpers
# ------------------------------------------------------------------------------

CURRENT_PYTHON_TEXT = f"Python {platform.python_version()}"


# ------------------------------------------------------------------------------
# Tool result
# ------------------------------------------------------------------------------

def test_tool_result_passes_when_the_line_starts_with_the_pin_and_a_space(bin1):
    write_stand_in(bin1, "tool1", 'echo "tool1 1.2.3 (build1)"')

    result = tools.tool_result("tool1", ["--version"], "tool1 1.2.3", environment_map=environment_with(bin1))

    assert result.passed
    assert str(bin1 / "tool1") in result.detail
    assert "tool1 1.2.3 (build1)" in result.detail


def test_tool_result_passes_when_the_line_equals_the_pin(bin1):
    write_stand_in(bin1, "tool1", 'echo "tool1 1.2.3"')

    result = tools.tool_result("tool1", ["--version"], "tool1 1.2.3", environment_map=environment_with(bin1))

    assert result.passed


def test_tool_result_fails_for_a_shorter_version(bin1):
    write_stand_in(bin1, "tool1", 'echo "tool1 1.2"')

    result = tools.tool_result("tool1", ["--version"], "tool1 1.2.3", environment_map=environment_with(bin1))

    assert not result.passed
    assert "tool1 reports 'tool1 1.2'; the pin is 'tool1 1.2.3'" in result.detail


def test_tool_result_fails_for_a_longer_version_with_the_rebuild_command(bin1):
    write_stand_in(bin1, "tool1", 'echo "tool1 1.2.30"')

    result = tools.tool_result("tool1", ["--version"], "tool1 1.2.3", environment_map=environment_with(bin1))

    assert not result.passed
    assert "tool1 reports 'tool1 1.2.30'; the pin is 'tool1 1.2.3'" in result.detail
    assert "sbx-upgrade" in result.hint


def test_tool_result_fails_when_the_version_command_exits_non_zero(bin1):
    write_stand_in(bin1, "tool1", 'echo "tool1 1.2.3"; exit 1')

    result = tools.tool_result("tool1", ["--version"], "tool1 1.2.3", environment_map=environment_with(bin1))

    assert not result.passed
    assert "the pin is" in result.detail


def test_tool_result_fails_when_the_required_text_is_missing(bin1):
    write_stand_in(bin1, "tool1", 'echo "tool1 1.2.3 (build1)"')

    result = tools.tool_result(
        "tool1", ["--version"], "tool1 1.2.3", required_text="vendor1", environment_map=environment_with(bin1)
    )

    assert not result.passed
    assert "tool1 output lacks 'vendor1'" in result.detail


def test_tool_result_passes_when_the_required_text_is_on_stderr(bin1):
    write_stand_in(bin1, "tool1", 'echo "tool1 1.2.3"; echo "vendor1" >&2')

    result = tools.tool_result(
        "tool1", ["--version"], "tool1 1.2.3", required_text="vendor1", environment_map=environment_with(bin1)
    )

    assert result.passed


def test_tool_result_fails_for_a_command_that_is_not_on_the_path(bin1):
    result = tools.tool_result("missing1", environment_map={"PATH": str(bin1)})

    assert not result.passed
    assert result.detail == "missing1 is not on PATH"
    assert "sbx-upgrade" in result.hint


def test_tool_result_fails_when_the_tool_resolves_under_the_forbidden_root(bin1):
    write_stand_in(bin1, "tool1", 'echo "tool1 1.2.3"')

    result = tools.tool_result("tool1", environment_map=environment_with(bin1), home_root=str(bin1.parent))

    assert not result.passed
    assert f"tool1 resolves to {bin1 / 'tool1'}, under {bin1.parent}, not the image" in result.detail
    assert "remove it" in result.hint


def test_tool_result_passes_for_a_tool_in_a_sibling_folder_that_shares_the_root_prefix(tmp_path):
    root1 = tmp_path / "home1"
    sibling1 = tmp_path / "home10"
    root1.mkdir()
    sibling1.mkdir()
    write_stand_in(sibling1, "tool1", 'echo "tool1 1.2.3"')

    result = tools.tool_result("tool1", environment_map=environment_with(sibling1), home_root=str(root1))

    assert result.passed


def test_tool_result_follows_a_link_to_the_real_file_before_judging_the_folder(tmp_path, bin1):
    real_dir = tmp_path / "real1"
    real_dir.mkdir()
    write_stand_in(real_dir, "tool1", 'echo "tool1 1.2.3"')
    (bin1 / "tool1").symlink_to(real_dir / "tool1")

    result = tools.tool_result("tool1", environment_map=environment_with(bin1), home_root=str(real_dir))

    assert not result.passed
    assert str(real_dir / "tool1") in result.detail


def test_tool_result_fails_for_a_binary_of_another_machine(bin1):
    other_machine_header = b"\x7fELF" + bytes(14) + (0x28).to_bytes(2, "little") + bytes(8)
    (bin1 / "tool1").write_bytes(other_machine_header)
    (bin1 / "tool1").chmod(0o755)

    result = tools.tool_result("tool1", environment_map=environment_with(bin1))

    assert not result.passed
    assert f"tool1 is built for ELF machine 0x28, not {platform.machine()}" in result.detail
    assert "sbx-upgrade" in result.hint


def test_tool_result_passes_for_a_file_shorter_than_an_elf_header(bin1):
    (bin1 / "tool1").write_bytes(b"\x7fELF")
    (bin1 / "tool1").chmod(0o755)

    assert tools.tool_result("tool1", environment_map=environment_with(bin1)).passed


def test_tool_result_passes_for_the_python_that_runs_the_checks():
    result = tools.tool_result("python3", ["--version"], CURRENT_PYTHON_TEXT)

    assert result.passed
    assert os.path.realpath(shutil.which("python3")) in result.detail


def test_tool_result_without_a_version_command_passes_with_the_resolved_path_only():
    result = tools.tool_result("git")

    assert result.passed
    assert result.detail == os.path.realpath(shutil.which("git"))
