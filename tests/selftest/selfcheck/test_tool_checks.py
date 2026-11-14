# Tests of the tool, version and versions-line helpers. They run real binaries
# (python3, git, bash) and, where a tool's output must vary, a small stand-in
# executable written into tmp_path and put first on the PATH of the environment
# passed in. Nothing is mocked.

import os
import platform
import shutil
import sys
from pathlib import Path

import pytest

import sbx_selfcheck
import shared_checks

CURRENT_PYTHON_TEXT = f"Python {platform.python_version()}"
TEMURIN_PIN1 = "eclipse-temurin:21.0.12_8-jdk-noble@sha256:abc"


def write_stand_in(folder: Path, name: str, script_body: str) -> Path:
    stand_in = folder / name
    stand_in.write_text("#!/bin/sh\n" + script_body + "\n")
    stand_in.chmod(0o755)

    return stand_in


def environment_with(folder: Path) -> dict[str, str]:
    return {"PATH": f"{folder}{os.pathsep}{os.environ['PATH']}"}


def write_versions(versions_file: Path, extra_line_list: list[str] | None = None) -> Path:
    line_list = [
        "GH_VERSION=2.102.0",
        "NODE_VERSION=24.21.0",
        "MAVEN_VERSION=3.9.11",
        "GSD_CORE_VERSION=1.15.0",
        f"TEMURIN_IMAGE={TEMURIN_PIN1}",
        "UV_IMAGE=ghcr.io/astral-sh/uv:0.12.21@sha256:abc",
        "BUNDLE_REPO_URL=https://example.test/repo1.git",
    ]

    if extra_line_list:
        line_list.extend(extra_line_list)

    versions_file.write_text("\n".join(line_list) + "\n")

    return versions_file


@pytest.fixture
def versions1(tmp_path) -> Path:
    return write_versions(tmp_path / "versions1.env")


@pytest.fixture
def bin1(tmp_path) -> Path:
    bin_dir = tmp_path / "bin1"
    bin_dir.mkdir()

    return bin_dir


def test_version_matches_accepts_equal_text_and_text_followed_by_a_space():
    assert sbx_selfcheck.version_matches("uv 0.12.21", "uv 0.12.21")
    assert sbx_selfcheck.version_matches("uv 0.12.21 (abc 2026-01-01)", "uv 0.12.21")


def test_version_matches_rejects_a_longer_or_shorter_version():
    assert not sbx_selfcheck.version_matches("uv 0.12.210", "uv 0.12.21")
    assert not sbx_selfcheck.version_matches("uv 0.12.2", "uv 0.12.21")


def test_is_under_accepts_the_root_itself_and_what_sits_below_it():
    assert sbx_selfcheck.is_under("/home/sandbox/x", "/home")
    assert sbx_selfcheck.is_under("/home", "/home")


def test_is_under_rejects_a_sibling_that_shares_the_prefix_and_other_roots():
    assert not sbx_selfcheck.is_under("/homeowner/x", "/home")
    assert not sbx_selfcheck.is_under("/usr/bin/git", "/home")


def test_image_tag_takes_the_text_after_the_last_colon_before_the_digest():
    assert sbx_selfcheck.image_tag("ghcr.io/astral-sh/uv:0.12.21@sha256:abc") == "0.12.21"
    assert sbx_selfcheck.image_tag(TEMURIN_PIN1) == "21.0.12_8-jdk-noble"
    assert sbx_selfcheck.image_tag("registry1:5000/image1:1.2@sha256:abc") == "1.2"


def test_jdk_version_is_the_tag_up_to_its_first_underscore():
    assert sbx_selfcheck.jdk_version(TEMURIN_PIN1) == "21.0.12"


def test_elf_machine_of_the_running_interpreter_is_the_machine_of_the_container():
    interpreter = Path(os.path.realpath(sys.executable))

    assert sbx_selfcheck.elf_machine(interpreter) == sbx_selfcheck.ELF_MACHINE_BY_UNAME_MAP[platform.machine()]


def test_elf_machine_of_a_text_file_is_none(tmp_path):
    text_file = tmp_path / "text1.txt"
    text_file.write_text("not a binary, but longer than twenty bytes\n")

    assert sbx_selfcheck.elf_machine(text_file) is None


def test_elf_machine_of_a_file_shorter_than_the_header_is_none(tmp_path):
    short_file = tmp_path / "short1"
    short_file.write_bytes(b"\x7fELF")

    assert sbx_selfcheck.elf_machine(short_file) is None


def test_first_output_line_takes_stdout_then_stderr(bin1):
    write_stand_in(bin1, "tool1", 'echo; echo "out1"; echo "err1" >&2')
    write_stand_in(bin1, "tool2", 'echo "err2" >&2')
    environment1 = environment_with(bin1)

    assert sbx_selfcheck.first_output_line(sbx_selfcheck.run_command(["tool1"], environment1)) == "out1"
    assert sbx_selfcheck.first_output_line(sbx_selfcheck.run_command(["tool2"], environment1)) == "err2"


def test_tool_result_passes_when_the_line_starts_with_the_pin_and_a_space(bin1):
    write_stand_in(bin1, "tool1", 'echo "tool1 1.2.3 (build1)"')

    result = sbx_selfcheck.tool_result("tool1", ["--version"], "tool1 1.2.3", environment=environment_with(bin1))

    assert result.passed
    assert str(bin1 / "tool1") in result.detail
    assert "tool1 1.2.3 (build1)" in result.detail


def test_tool_result_fails_for_a_longer_version_with_the_rebuild_command(bin1):
    write_stand_in(bin1, "tool1", 'echo "tool1 1.2.30"')

    result = sbx_selfcheck.tool_result("tool1", ["--version"], "tool1 1.2.3", environment=environment_with(bin1))

    assert not result.passed
    assert "tool1 reports 'tool1 1.2.30'; the pin is 'tool1 1.2.3'" in result.detail
    assert "sbx-upgrade" in result.hint


def test_tool_result_fails_when_the_version_command_exits_non_zero(bin1):
    write_stand_in(bin1, "tool1", 'echo "tool1 1.2.3"; exit 1')

    result = sbx_selfcheck.tool_result("tool1", ["--version"], "tool1 1.2.3", environment=environment_with(bin1))

    assert not result.passed
    assert "the pin is" in result.detail


def test_tool_result_fails_when_the_required_text_is_missing(bin1):
    write_stand_in(bin1, "tool1", 'echo "tool1 1.2.3 (build1)"')

    result = sbx_selfcheck.tool_result(
        "tool1", ["--version"], "tool1 1.2.3", required_text="vendor1", environment=environment_with(bin1)
    )

    assert not result.passed
    assert "tool1 output lacks 'vendor1'" in result.detail


def test_tool_result_passes_when_the_required_text_is_on_stderr(bin1):
    write_stand_in(bin1, "tool1", 'echo "tool1 1.2.3"; echo "vendor1" >&2')

    result = sbx_selfcheck.tool_result(
        "tool1", ["--version"], "tool1 1.2.3", required_text="vendor1", environment=environment_with(bin1)
    )

    assert result.passed


def test_tool_result_fails_for_a_command_that_is_not_on_the_path(bin1):
    result = sbx_selfcheck.tool_result("missing1", environment={"PATH": str(bin1)})

    assert not result.passed
    assert result.detail == "missing1 is not on PATH"
    assert "sbx-upgrade" in result.hint


def test_tool_result_fails_when_the_tool_resolves_under_the_forbidden_root(bin1):
    write_stand_in(bin1, "tool1", 'echo "tool1 1.2.3"')

    result = sbx_selfcheck.tool_result("tool1", environment=environment_with(bin1), home_root=str(bin1.parent))

    assert not result.passed
    assert f"tool1 resolves to {bin1 / 'tool1'}, under {bin1.parent}, not the image" in result.detail
    assert "remove it" in result.hint


def test_tool_result_follows_a_link_to_the_real_file_before_judging_the_folder(tmp_path, bin1):
    real_dir = tmp_path / "real1"
    real_dir.mkdir()
    write_stand_in(real_dir, "tool1", 'echo "tool1 1.2.3"')
    (bin1 / "tool1").symlink_to(real_dir / "tool1")

    result = sbx_selfcheck.tool_result("tool1", environment=environment_with(bin1), home_root=str(real_dir))

    assert not result.passed
    assert str(real_dir / "tool1") in result.detail


def test_tool_result_fails_for_a_binary_of_another_machine(bin1):
    other_machine_header = b"\x7fELF" + bytes(14) + (0x28).to_bytes(2, "little") + bytes(8)
    (bin1 / "tool1").write_bytes(other_machine_header)
    (bin1 / "tool1").chmod(0o755)

    result = sbx_selfcheck.tool_result("tool1", environment=environment_with(bin1))

    assert not result.passed
    assert f"tool1 is built for ELF machine 0x28, not {platform.machine()}" in result.detail
    assert "sbx-upgrade" in result.hint


def test_tool_result_passes_for_the_python_that_runs_the_checks():
    result = sbx_selfcheck.tool_result("python3", ["--version"], CURRENT_PYTHON_TEXT)

    assert result.passed
    assert os.path.realpath(shutil.which("python3")) in result.detail


def test_tool_result_without_a_version_command_passes_with_the_resolved_path_only():
    result = sbx_selfcheck.tool_result("git")

    assert result.passed
    assert result.detail == os.path.realpath(shutil.which("git"))


def test_architecture_passes_with_the_machine_and_its_elf_value():
    result = shared_checks.architecture_result()

    assert result.passed
    assert result.detail.startswith(f"{platform.machine()}, ELF machine 0x")


def test_tool_gh_without_its_pin_reports_the_missing_pin_and_runs_nothing(tmp_path):
    empty_versions = tmp_path / "empty1.env"
    empty_versions.write_text("")

    result = shared_checks.tool_gh_result(empty_versions)

    assert not result.passed
    assert result.detail == f"GH_VERSION is not in {sbx_selfcheck.VERSIONS_FILE}"


def test_pinned_tool_lines_report_their_missing_pin(tmp_path):
    empty_versions = tmp_path / "empty1.env"
    empty_versions.write_text("")

    for pin_name, function in [
        ("NODE_VERSION", shared_checks.tool_node_result),
        ("UV_IMAGE", shared_checks.tool_uv_result),
        ("TEMURIN_IMAGE", shared_checks.tool_java_result),
        ("MAVEN_VERSION", shared_checks.tool_maven_result),
        ("GSD_CORE_VERSION", shared_checks.tool_gsd_result),
    ]:
        result = function(empty_versions)

        assert not result.passed
        assert result.detail.startswith(f"{pin_name} is not in ")


@pytest.mark.skipif(shutil.which("node") is None, reason="node is not installed here")
def test_tool_node_fails_when_the_pin_differs_from_the_installed_version(tmp_path):
    versions2 = write_versions(tmp_path / "versions2.env")
    versions2.write_text(versions2.read_text().replace("NODE_VERSION=24.21.0", "NODE_VERSION=0.0.1"))

    result = shared_checks.tool_node_result(versions2)

    assert not result.passed
    assert "the pin is 'v0.0.1'" in result.detail


def test_tzdata_passes_when_the_utc_zone_file_exists(tmp_path):
    utc_file = tmp_path / "UTC"
    utc_file.write_text("zone1")

    assert shared_checks.tzdata_result(utc_file).passed
    assert not shared_checks.tzdata_result(tmp_path / "missing1").passed


def test_every_tool_line_has_a_check_of_its_own():
    name_list = [check.name for check in shared_checks.CHECK_LIST]

    for tool in [
        "git", "gh", "node", "python", "uv", "java", "maven", "gsd", "jq", "rg", "unzip", "zip", "ssh", "make", "gcc",
    ]:
        assert f"tool-{tool}" in name_list

    assert "tool-versions" not in name_list
