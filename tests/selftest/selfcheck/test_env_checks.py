# Tests of the shared environment checks.

import checks_env
import selfcheck_core


def test_bundle_env_passes_when_the_url_matches_the_pin_and_the_dir_is_the_clone(tmp_path):
    versions1 = tmp_path / "versions1"
    versions1.write_text("BUNDLE_REPO_URL=https://example.invalid/repo1.git\n")
    environment1 = {"BUNDLE_REPO_URL": "https://example.invalid/repo1.git", "SBX_BUNDLE_DIR": str(selfcheck_core.BUNDLE_DIR)}

    assert checks_env.bundle_env_result(versions1, environment1).passed


def test_bundle_env_fails_naming_the_wrong_one(tmp_path):
    versions1 = tmp_path / "versions1"
    versions1.write_text("BUNDLE_REPO_URL=https://example.invalid/repo1.git\n")
    environment1 = {"BUNDLE_REPO_URL": "https://example.invalid/repo2.git", "SBX_BUNDLE_DIR": str(selfcheck_core.BUNDLE_DIR)}

    result = checks_env.bundle_env_result(versions1, environment1)

    assert not result.passed
    assert "BUNDLE_REPO_URL" in result.detail
    assert "SBX_BUNDLE_DIR" not in result.detail


def test_bundle_env_fails_through_the_missing_pin_when_the_pin_is_absent(tmp_path):
    versions1 = tmp_path / "versions1"
    versions1.write_text("OTHER1=value1\n")

    result = checks_env.bundle_env_result(versions1, {})

    assert not result.passed
    assert "BUNDLE_REPO_URL is not in" in result.detail



