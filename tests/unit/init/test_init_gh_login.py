# --------------------------------------------------------------------------------
# Tests of sbx-gh-login: it points at sbx-init when the state directories are missing
# --------------------------------------------------------------------------------
# The real script runs under bash with a stand-in gh on a temp PATH. The git
# config file sits in tmp_path, so the dev sandbox's git config is never touched.
# --------------------------------------------------------------------------------

import os
import subprocess
from pathlib import Path

from init_helpers import REPO_DIR, environment_with, write_stand_in

SCRIPT_PATH = REPO_DIR / "base/bin/sbx-gh-login"
PRECONDITION_LINE = "[sbx] ERROR: the state directories do not exist yet; run sbx-init first.\n"


# --------------------------------------------------------------------------------
# Helpers
# --------------------------------------------------------------------------------

def make_sandbox(base_dir: Path) -> dict:
    stand_in_dir = base_dir / "stand-ins"
    stand_in_dir.mkdir()
    gh_log_file = base_dir / "gh-calls.txt"
    write_stand_in(stand_in_dir, "gh", f'echo "$*" >> "{gh_log_file}"')
    environment = dict(os.environ)
    environment.update(environment_with(stand_in_dir))
    environment["GH_CONFIG_DIR"] = str(base_dir / "state1" / "gh")
    environment["GIT_CONFIG_GLOBAL"] = str(base_dir / "state1" / "git" / "config")
    environment["GIT_CONFIG_NOSYSTEM"] = "1"

    return {"environment": environment, "gh_log_file": gh_log_file}


# --------------------------------------------------------------------------------

def run_login(sandbox: dict):
    return subprocess.run(
        ["bash", str(SCRIPT_PATH)],
        env=sandbox["environment"],
        capture_output=True,
        text=True,
        stdin=subprocess.DEVNULL,
        timeout=60,
    )


# --------------------------------------------------------------------------------

def make_gh_dir(sandbox: dict) -> None:
    Path(sandbox["environment"]["GH_CONFIG_DIR"]).mkdir(parents=True)


# --------------------------------------------------------------------------------

def make_git_dir(sandbox: dict) -> None:
    Path(sandbox["environment"]["GIT_CONFIG_GLOBAL"]).parent.mkdir(parents=True)


# --------------------------------------------------------------------------------
# A missing state directory stops the script before gh runs
# --------------------------------------------------------------------------------

def test_a_missing_gh_config_dir_stops_before_gh_runs(tmp_path):
    sandbox = make_sandbox(tmp_path)
    make_git_dir(sandbox)

    result = run_login(sandbox)

    assert result.returncode == 1
    assert result.stderr == PRECONDITION_LINE
    assert not sandbox["gh_log_file"].exists()


# --------------------------------------------------------------------------------

def test_a_git_config_in_a_missing_dir_stops_before_gh_runs(tmp_path):
    sandbox = make_sandbox(tmp_path)
    make_gh_dir(sandbox)

    result = run_login(sandbox)

    assert result.returncode == 1
    assert result.stderr == PRECONDITION_LINE
    assert not sandbox["gh_log_file"].exists()


# --------------------------------------------------------------------------------
# Both directories present: gh runs as before
# --------------------------------------------------------------------------------

def test_with_both_dirs_gh_logs_in_and_sets_up_git_and_name_and_email_stay_unset(tmp_path):
    sandbox = make_sandbox(tmp_path)
    make_gh_dir(sandbox)
    make_git_dir(sandbox)

    result = run_login(sandbox)

    gh_call_list = sandbox["gh_log_file"].read_text().splitlines()
    assert result.returncode == 0
    assert gh_call_list == [
        "auth login --hostname github.com --git-protocol https",
        "auth setup-git",
    ]
    assert "git user.name is not set and there is no terminal to ask." in result.stderr
    assert "git user.email is not set and there is no terminal to ask." in result.stderr
