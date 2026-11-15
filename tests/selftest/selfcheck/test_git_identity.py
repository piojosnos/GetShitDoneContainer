# ------------------------------------------------------------------------------
# Tests of the git identity check
# ------------------------------------------------------------------------------
# They run the real git against config files inside tmp_path.
# ------------------------------------------------------------------------------

import subprocess

from helpers import git_environment, load_shared_check

git_identity = load_shared_check("100_git_identity")


# ------------------------------------------------------------------------------
# Git identity
# ------------------------------------------------------------------------------

def test_git_identity_fails_for_an_empty_config_and_then_passes_without_printing_values(tmp_path):
    global1 = tmp_path / "global1"
    global1.write_text("")
    environment1 = git_environment(tmp_path / "system1", global1)

    empty_result = git_identity.git_identity_result(environment1)

    assert not empty_result.passed
    assert "user.name" in empty_result.detail
    assert "user.email" in empty_result.detail
    assert "sbx-gh-login" in empty_result.hint

    subprocess.run(["git", "config", "--file", str(global1), "user.name", "name1"], check=True, env=environment1)
    subprocess.run(["git", "config", "--file", str(global1), "user.email", "name1@example.invalid"], check=True, env=environment1)

    set_result = git_identity.git_identity_result(environment1)

    assert set_result.passed
    assert "name1@example.invalid" not in set_result.detail + set_result.hint
    assert "name1" not in set_result.detail.replace("user.name", "")


def test_git_identity_names_only_the_empty_one(tmp_path):
    global1 = tmp_path / "global1"
    environment1 = git_environment(tmp_path / "system1", global1)
    subprocess.run(["git", "config", "--file", str(global1), "user.name", "name1"], check=True, env=environment1)

    result = git_identity.git_identity_result(environment1)

    assert not result.passed
    assert "user.email" in result.detail
    assert "user.name" not in result.detail
