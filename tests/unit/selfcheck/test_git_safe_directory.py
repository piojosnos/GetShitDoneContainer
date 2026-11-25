# --------------------------------------------------------------------------------
# Tests of the git safe directory check
# --------------------------------------------------------------------------------
# They run the real git against config files inside tmp_path.
# --------------------------------------------------------------------------------

from helpers import git_environment, load_shared_check

git_safe_directory = load_shared_check("090_git_safe_directory")


# --------------------------------------------------------------------------------
# Git safe directory
# --------------------------------------------------------------------------------

def test_safe_directory_passes_when_the_system_file_trusts_every_dir(tmp_path):
    system1 = tmp_path / "system1"
    system1.write_text("[safe]\n\tdirectory = *\n")

    result = git_safe_directory.safe_directory_result(git_environment(system1, tmp_path / "global1"))

    assert result.passed


def test_safe_directory_fails_when_the_system_file_trusts_one_dir(tmp_path):
    system1 = tmp_path / "system1"
    system1.write_text("[safe]\n\tdirectory = /dir1\n")

    result = git_safe_directory.safe_directory_result(git_environment(system1, tmp_path / "global1"))

    assert not result.passed
    assert "on the host run: sbx-upgrade" in result.hint


def test_safe_directory_fails_when_the_system_file_is_empty(tmp_path):
    system1 = tmp_path / "system1"
    system1.write_text("")

    assert not git_safe_directory.safe_directory_result(git_environment(system1, tmp_path / "global1")).passed
