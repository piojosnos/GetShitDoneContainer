# ------------------------------------------------------------------------------
# Tests of the agent config result
# ------------------------------------------------------------------------------
# Real files inside tmp_path. A planted login token must show up nowhere in a result.
# ------------------------------------------------------------------------------

from pathlib import Path

import agent_config
import hints


# ------------------------------------------------------------------------------
# Constants and helpers
# ------------------------------------------------------------------------------

GSD_PIN1 = "1.15.0"


TOKEN_TEXT1 = "token1"


def write_gsd_pin(folder: Path, version: str = GSD_PIN1) -> Path:
    versions_file = folder / "versions1.env"
    versions_file.write_text(f"GSD_CORE_VERSION={version}\n")

    return versions_file


def write_synced_version(config_dir: Path, version: str) -> None:
    version_file = config_dir / "gsd-core" / "VERSION"
    version_file.parent.mkdir(parents=True, exist_ok=True)
    version_file.write_text(version + "\n")


# ------------------------------------------------------------------------------
# Login file and GSD sync
# ------------------------------------------------------------------------------

def test_login_file_result_passes_for_a_non_empty_file_and_never_shows_its_text(tmp_path):
    login_file1 = tmp_path / "login1.json"
    login_file1.write_text('{"fake":"' + TOKEN_TEXT1 + '"}')

    result = agent_config.login_file_result(login_file1, "hint1")

    assert result.passed
    assert str(login_file1) in result.detail
    assert TOKEN_TEXT1 not in result.detail + result.hint


def test_login_file_result_fails_with_the_hint_for_an_empty_or_missing_file(tmp_path):
    empty_file1 = tmp_path / "empty1.json"
    empty_file1.write_text("")

    empty_result = agent_config.login_file_result(empty_file1, "hint1")
    missing_result = agent_config.login_file_result(tmp_path / "missing1.json", "hint1")

    assert not empty_result.passed
    assert empty_result.hint == "hint1"
    assert not missing_result.passed
    assert missing_result.hint == "hint1"


def test_login_file_result_never_opens_the_file(tmp_path):
    login_dir1 = tmp_path / "login1.json"
    login_dir1.mkdir()
    (login_dir1 / "inner1").write_text(TOKEN_TEXT1)

    result = agent_config.login_file_result(login_dir1, "hint1")

    assert not result.passed
    assert TOKEN_TEXT1 not in result.detail + result.hint


def test_gsd_synced_result_passes_when_the_synced_version_is_the_pin(tmp_path):
    config1 = tmp_path / "config1"
    write_synced_version(config1, GSD_PIN1)

    result = agent_config.gsd_synced_result(config1, write_gsd_pin(tmp_path))

    assert result.passed
    assert GSD_PIN1 in result.detail


def test_gsd_synced_result_fails_for_another_version_and_for_a_missing_file(tmp_path):
    versions1 = write_gsd_pin(tmp_path)
    config1 = tmp_path / "config1"
    config2 = tmp_path / "config2"
    write_synced_version(config1, "1.14.0")
    config2.mkdir()

    other_result = agent_config.gsd_synced_result(config1, versions1)
    missing_result = agent_config.gsd_synced_result(config2, versions1)

    assert not other_result.passed
    assert "1.14.0" in other_result.detail
    assert other_result.hint == hints.init_hint()
    assert not missing_result.passed
    assert missing_result.hint == hints.init_hint()


def test_gsd_synced_result_fails_when_the_pin_is_missing(tmp_path):
    versions1 = tmp_path / "versions1.env"
    versions1.write_text("NODE_VERSION=1\n")
    config1 = tmp_path / "config1"
    write_synced_version(config1, GSD_PIN1)

    result = agent_config.gsd_synced_result(config1, versions1)

    assert not result.passed
    assert "GSD_CORE_VERSION" in result.detail
