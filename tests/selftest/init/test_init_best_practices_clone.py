# ------------------------------------------------------------------------------
# Tests of sbx-best-practices-clone: clone the best-practices repo, then run sbx-init
# ------------------------------------------------------------------------------
# The real script runs under bash with real git against a local bare origin in
# tmp_path. A stand-in sbx-init on a temp PATH records that it ran.
# ------------------------------------------------------------------------------

import os
import subprocess
from pathlib import Path

from init_helpers import REPO_DIR, environment_with, write_stand_in

SCRIPT_PATH = REPO_DIR / "base/bin/sbx-best-practices-clone"
GIT_IDENTITY_ARGUMENT_LIST = ["-c", "user.name=test1", "-c", "user.email=test1@example.invalid"]


# ------------------------------------------------------------------------------
# Helpers
# ------------------------------------------------------------------------------

def run_git(argument_list: list[str], working_dir: Path) -> None:
    subprocess.run(["git", *argument_list], cwd=working_dir, check=True, capture_output=True)


def make_origin(base_dir: Path) -> Path:
    seed_dir = base_dir / "seed1"
    (seed_dir / "rules").mkdir(parents=True)
    (seed_dir / "skills" / "skill1").mkdir(parents=True)
    (seed_dir / "rules" / "rule1.md").write_text("rule1\n")
    (seed_dir / "skills" / "skill1" / "SKILL.md").write_text("skill1\n")
    run_git(["init", "-q", "-b", "main"], seed_dir)
    run_git(["add", "."], seed_dir)
    run_git([*GIT_IDENTITY_ARGUMENT_LIST, "commit", "-q", "-m", "seed1"], seed_dir)
    origin_dir = base_dir / "origin1.git"
    run_git(["clone", "-q", "--bare", str(seed_dir), str(origin_dir)], base_dir)

    return origin_dir


def make_sandbox(base_dir: Path, init_status: int = 0) -> dict:
    stand_in_dir = base_dir / "stand-ins"
    stand_in_dir.mkdir()
    init_log_file = base_dir / "init-runs.txt"
    write_stand_in(stand_in_dir, "sbx-init", f'echo run >> "{init_log_file}"\nexit {init_status}')
    environment = dict(os.environ)
    environment.update(environment_with(stand_in_dir))
    environment["GIT_CONFIG_GLOBAL"] = str(base_dir / "gitconfig1")
    environment["GIT_CONFIG_NOSYSTEM"] = "1"

    return {
        "environment": environment,
        "init_log_file": init_log_file,
        "clone_dir": base_dir / "best-practices",
    }


def run_clone(sandbox: dict, origin_url: str):
    environment = dict(sandbox["environment"])
    environment["BEST_PRACTICES_REPO_URL"] = origin_url
    environment["SBX_BEST_PRACTICES_DIR"] = str(sandbox["clone_dir"])

    return subprocess.run(
        ["bash", str(SCRIPT_PATH)],
        env=environment,
        capture_output=True,
        text=True,
        stdin=subprocess.DEVNULL,
        timeout=60,
    )


def init_run_count(sandbox: dict) -> int:
    if not sandbox["init_log_file"].exists():
        return 0

    return len(sandbox["init_log_file"].read_text().splitlines())


# ------------------------------------------------------------------------------
# A fresh clone, then sbx-init
# ------------------------------------------------------------------------------

def test_a_clone_is_followed_by_one_sbx_init_run_and_exits_zero(tmp_path):
    origin_dir = make_origin(tmp_path)
    sandbox = make_sandbox(tmp_path)

    result = run_clone(sandbox, str(origin_dir))

    assert result.returncode == 0
    assert (sandbox["clone_dir"] / "rules" / "rule1.md").read_text() == "rule1\n"
    assert init_run_count(sandbox) == 1


def test_the_exit_status_is_the_one_of_sbx_init(tmp_path):
    origin_dir = make_origin(tmp_path)
    sandbox = make_sandbox(tmp_path, init_status=3)

    result = run_clone(sandbox, str(origin_dir))

    assert result.returncode == 3
    assert init_run_count(sandbox) == 1


# ------------------------------------------------------------------------------
# An existing folder is refused
# ------------------------------------------------------------------------------

def test_a_second_run_is_refused_names_sbx_init_and_does_not_run_it_again(tmp_path):
    origin_dir = make_origin(tmp_path)
    sandbox = make_sandbox(tmp_path)
    run_clone(sandbox, str(origin_dir))

    result = run_clone(sandbox, str(origin_dir))

    assert result.returncode == 1
    assert "already exists; nothing was changed" in result.stderr
    assert "To relink it: sbx-init" in result.stderr
    assert init_run_count(sandbox) == 1


# ------------------------------------------------------------------------------
# A missing origin
# ------------------------------------------------------------------------------

def test_a_missing_origin_fails_names_sbx_gh_login_and_leaves_no_folder(tmp_path):
    sandbox = make_sandbox(tmp_path)

    result = run_clone(sandbox, str(tmp_path / "missing1.git"))

    assert result.returncode == 1
    assert "sbx-gh-login" in result.stderr
    assert not sandbox["clone_dir"].exists()
    assert init_run_count(sandbox) == 0
