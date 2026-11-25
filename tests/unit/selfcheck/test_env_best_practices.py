# --------------------------------------------------------------------------------
# Tests of the best-practices environment check
# --------------------------------------------------------------------------------

import paths
from helpers import load_shared_check

env_best_practices = load_shared_check("120_env_best_practices")


# --------------------------------------------------------------------------------
# Best-practices environment
# --------------------------------------------------------------------------------

def test_best_practices_env_passes_when_the_url_matches_the_pin_and_the_dir_is_the_clone(tmp_path):
    versions1 = tmp_path / "versions1"
    versions1.write_text("BEST_PRACTICES_REPO_URL=https://example.invalid/repo1.git\n")
    environment1 = {"BEST_PRACTICES_REPO_URL": "https://example.invalid/repo1.git", "SBX_BEST_PRACTICES_DIR": str(paths.BEST_PRACTICES_DIR)}

    assert env_best_practices.best_practices_env_result(versions1, environment1).passed


# --------------------------------------------------------------------------------

def test_best_practices_env_fails_naming_the_wrong_one(tmp_path):
    versions1 = tmp_path / "versions1"
    versions1.write_text("BEST_PRACTICES_REPO_URL=https://example.invalid/repo1.git\n")
    environment1 = {"BEST_PRACTICES_REPO_URL": "https://example.invalid/repo2.git", "SBX_BEST_PRACTICES_DIR": str(paths.BEST_PRACTICES_DIR)}

    result = env_best_practices.best_practices_env_result(versions1, environment1)

    assert not result.passed
    assert "BEST_PRACTICES_REPO_URL" in result.detail
    assert "SBX_BEST_PRACTICES_DIR" not in result.detail


# --------------------------------------------------------------------------------

def test_best_practices_env_fails_through_the_missing_pin_when_the_pin_is_absent(tmp_path):
    versions1 = tmp_path / "versions1"
    versions1.write_text("OTHER1=value1\n")

    result = env_best_practices.best_practices_env_result(versions1, {})

    assert not result.passed
    assert "BEST_PRACTICES_REPO_URL is not in" in result.detail
