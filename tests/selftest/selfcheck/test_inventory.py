# ------------------------------------------------------------------------------
# Tests of the check inventory
# ------------------------------------------------------------------------------
# They tie the check lists to the counts H-34 expects and keep every name unique
# and well formed. The lists load through the runner's own loader.
# ------------------------------------------------------------------------------

import re
import shutil
from pathlib import Path

import sbx_selfcheck
import selfcheck_core
import shared_checks

NAME_PATTERN = re.compile(r"^[a-z0-9]+(-[a-z0-9]+)*$")
SHARED_CHECK_COUNT = 41
CLAUDE_CHECK_COUNT = 12
CURSOR_CHECK_COUNT = 10


def expected_count(repo_dir: Path, constant_name: str) -> int:
    host_test_file = repo_dir / "tests" / "host" / "h34-selfcheck.sh"

    for line in host_test_file.read_text().splitlines():
        if line.startswith(constant_name + "="):
            return int(line.partition("=")[2].strip())

    raise AssertionError(f"{constant_name} is not set in {host_test_file}")


# ------------------------------------------------------------------------------
# Inventory
# ------------------------------------------------------------------------------

def test_the_lists_hold_the_declared_check_counts(agent_module):
    assert len(shared_checks.CHECK_LIST) == SHARED_CHECK_COUNT
    assert len(agent_module("claude").CHECK_LIST) == CLAUDE_CHECK_COUNT
    assert len(agent_module("cursor").CHECK_LIST) == CURSOR_CHECK_COUNT


def test_the_shared_list_plus_each_agent_list_equals_the_count_h34_expects(agent_module, repo_dir):
    claude_total = len(shared_checks.CHECK_LIST) + len(agent_module("claude").CHECK_LIST)
    cursor_total = len(shared_checks.CHECK_LIST) + len(agent_module("cursor").CHECK_LIST)

    assert claude_total == expected_count(repo_dir, "expectedClaudeCount")
    assert cursor_total == expected_count(repo_dir, "expectedCursorCount")


def test_no_name_repeats_within_one_image(agent_module):
    for agent_name in ["claude", "cursor"]:
        name_list = []

        for check in shared_checks.CHECK_LIST + agent_module(agent_name).CHECK_LIST:
            name_list.append(check.name)

        assert len(name_list) == len(set(name_list)), agent_name


def test_every_name_is_lowercase_words_joined_by_hyphens_and_none_says_skip(agent_module):
    for check_list in [shared_checks.CHECK_LIST, agent_module("claude").CHECK_LIST, agent_module("cursor").CHECK_LIST]:
        for check in check_list:
            assert NAME_PATTERN.match(check.name), check.name
            assert "skip" not in check.name, check.name


def test_every_entry_is_a_check_with_a_callable_function(agent_module):
    for check_list in [shared_checks.CHECK_LIST, agent_module("claude").CHECK_LIST, agent_module("cursor").CHECK_LIST]:
        for check in check_list:
            assert isinstance(check, selfcheck_core.Check)
            assert callable(check.function)


def test_collect_checks_loads_both_agent_files_without_a_load_failure(repo_dir, tmp_path):
    folder1 = tmp_path / "folder1"
    folder1.mkdir()
    shutil.copy(repo_dir / "claude" / "selfcheck" / "claude.py", folder1)
    shutil.copy(repo_dir / "cursor" / "selfcheck" / "cursor.py", folder1)

    check_list = sbx_selfcheck.collect_checks(shared_checks.CHECK_LIST, folder1)

    assert len(check_list) == SHARED_CHECK_COUNT + CLAUDE_CHECK_COUNT + CURSOR_CHECK_COUNT

    for check in check_list:
        assert not check.name.startswith("load-"), check.name


def test_the_shared_list_holds_the_checks_in_the_final_order(check_name_list_of):
    name_list = check_name_list_of(shared_checks.CHECK_LIST)

    assert name_list == [
        "workspace-mount",
        "project-folder",
        "state-folders",
        "state-writable",
        "no-root-owned-state",
        "user-sandbox",
        "home-layout",
        "home-owners",
        "architecture",
        "git-safe-directory",
        "git-identity",
        "env-state-paths",
        "env-bundle",
        "java-home",
        "tool-git",
        "tool-bash",
        "tool-gh",
        "tool-node",
        "tool-python",
        "tool-uv",
        "tool-java",
        "tool-keytool",
        "tool-maven",
        "tool-gsd",
        "tool-jq",
        "tool-rg",
        "tool-unzip",
        "tool-zip",
        "tool-ssh",
        "tool-make",
        "tool-gcc",
        "tzdata",
        "versions-record",
        "versions-line-file",
        "versions-line-interactive",
        "versions-line-quiet",
        "wrappers-root-owned",
        "image-paths-protected",
        "no-bundle-copy",
        "extra-ca-system-bundle",
        "extra-ca-java-cacerts",
    ]
