# --------------------------------------------------------------------------------
# Tests of the check inventory
# --------------------------------------------------------------------------------
# They tie the check lists to the counts the integration scenarios expect and
# keep every name unique and well formed. The lists load through the runner's
# own loader, and every check file name starts with a three-digit order prefix.
# --------------------------------------------------------------------------------

import re
import shutil

import check_result
import runner
from agent_specs import AGENT_SPEC_BY_NAME_MAP
from helpers import SHARED_CHECKS_DIR, agent_checks_dir


# --------------------------------------------------------------------------------
# Constants and helpers
# --------------------------------------------------------------------------------

NAME_PATTERN = re.compile(r"^[a-z0-9]+(-[a-z0-9]+)*$")
NAME_FILE_PATTERN = re.compile(r"^[0-9]{3}_[a-z0-9_]+\.py$")
SHARED_CHECK_COUNT = 42
CLAUDE_CHECK_COUNT = 13
CURSOR_CHECK_COUNT = 11


# --------------------------------------------------------------------------------
# Inventory
# --------------------------------------------------------------------------------

def test_the_lists_hold_the_declared_check_counts(shared_check_list, agent_check_list_of):
    assert len(shared_check_list) == SHARED_CHECK_COUNT
    assert len(agent_check_list_of("claude")) == CLAUDE_CHECK_COUNT
    assert len(agent_check_list_of("cursor")) == CURSOR_CHECK_COUNT


def test_the_shared_list_plus_each_agent_list_equals_the_count_the_agent_spec_expects(shared_check_list, agent_check_list_of):
    claude_total = len(shared_check_list) + len(agent_check_list_of("claude"))
    cursor_total = len(shared_check_list) + len(agent_check_list_of("cursor"))

    assert claude_total == AGENT_SPEC_BY_NAME_MAP["claude"].selfcheck_count
    assert cursor_total == AGENT_SPEC_BY_NAME_MAP["cursor"].selfcheck_count


def test_no_name_repeats_within_one_image(shared_check_list, agent_check_list_of):
    for agent_name in ["claude", "cursor"]:
        name_list = []

        for check in shared_check_list + agent_check_list_of(agent_name):
            name_list.append(check.name)

        assert len(name_list) == len(set(name_list)), agent_name


def test_every_name_is_lowercase_words_joined_by_hyphens_and_none_says_skip(shared_check_list, agent_check_list_of):
    for check_list in [shared_check_list, agent_check_list_of("claude"), agent_check_list_of("cursor")]:
        for check in check_list:
            assert NAME_PATTERN.match(check.name), check.name
            assert "skip" not in check.name, check.name


def test_every_entry_is_a_check_with_a_callable_function(shared_check_list, agent_check_list_of):
    for check_list in [shared_check_list, agent_check_list_of("claude"), agent_check_list_of("cursor")]:
        for check in check_list:
            assert isinstance(check, check_result.Check)
            assert callable(check.function)


def test_collect_checks_loads_both_agent_dirs_without_a_load_failure(repo_dir, tmp_path):
    dir1 = tmp_path / "dir1"
    dir1.mkdir()
    shutil.copytree(repo_dir / "claude" / "selfcheck", dir1 / "claude")
    shutil.copytree(repo_dir / "cursor" / "selfcheck", dir1 / "cursor")

    check_list = runner.collect_checks(SHARED_CHECKS_DIR, dir1)

    assert len(check_list) == SHARED_CHECK_COUNT + CLAUDE_CHECK_COUNT + CURSOR_CHECK_COUNT

    for check in check_list:
        assert not check.name.startswith("load-"), check.name


def test_the_shared_list_holds_the_checks_in_file_name_order(shared_check_list, check_name_list_of):
    name_list = check_name_list_of(shared_check_list)

    assert name_list == [
        "workspace-mount",
        "project-dir",
        "state-dirs",
        "state-writable",
        "init-marker",
        "no-root-owned-state",
        "user-sandbox",
        "home-layout",
        "home-owners",
        "architecture",
        "git-safe-directory",
        "git-identity",
        "env-state-paths",
        "env-best-practices",
        "java-home",
        "tool-git",
        "tool-bash",
        "tool-keytool",
        "tool-jq",
        "tool-rg",
        "tool-unzip",
        "tool-zip",
        "tool-ssh",
        "tool-make",
        "tool-gcc",
        "tool-gh",
        "tool-node",
        "tool-python",
        "tool-uv",
        "tool-java",
        "tool-maven",
        "tool-gsd",
        "tzdata",
        "versions-record",
        "versions-line-file",
        "versions-line-interactive",
        "versions-line-quiet",
        "image-root-owned",
        "image-paths-protected",
        "no-best-practices-copy",
        "extra-ca-system-bundle",
        "extra-ca-java-cacerts",
    ]


def test_every_tool_line_has_a_check_of_its_own(shared_check_list, check_name_list_of):
    name_list = check_name_list_of(shared_check_list)

    for tool in [
        "git", "bash", "gh", "node", "python", "uv", "java", "keytool", "maven", "gsd", "jq", "rg", "unzip", "zip", "ssh",
        "make", "gcc",
    ]:
        assert f"tool-{tool}" in name_list

    assert "tool-versions" not in name_list


def test_every_shared_check_file_is_named_with_a_three_digit_prefix_and_ends_in_a_check_list():
    for check_file in sorted(SHARED_CHECKS_DIR.glob("*.py")):
        assert NAME_FILE_PATTERN.match(check_file.name), check_file.name
        assert "\nCHECK_LIST" in check_file.read_text(), check_file.name


def test_the_claude_check_names_are_the_thirteen_in_order(agent_check_list_of, check_name_list_of):
    assert check_name_list_of(agent_check_list_of("claude")) == [
        "tool-claude",
        "claude-off-path",
        "tool-ccusage",
        "claude-env",
        "claude-home-links",
        "claude-credentials",
        "claude-gsd-synced",
        "claude-best-practices-links",
        "claude-image-root-owned",
        "claude-image-paths-protected",
        "claude-versions-line",
        "claude-no-home-copy",
        "claude-managed-settings",
    ]


def test_the_cursor_check_names_are_the_eleven_in_order(agent_check_list_of, check_name_list_of):
    assert check_name_list_of(agent_check_list_of("cursor")) == [
        "tool-cursor-agent",
        "cursor-off-path",
        "cursor-env",
        "cursor-home-links",
        "cursor-credentials",
        "cursor-gsd-synced",
        "cursor-best-practices-links",
        "cursor-image-root-owned",
        "cursor-image-paths-protected",
        "cursor-versions-line",
        "cursor-self-update-off",
    ]


def test_every_agent_check_file_is_named_with_a_three_digit_prefix_and_ends_in_a_check_list():
    for agent_name in ["claude", "cursor"]:
        for check_file in sorted(agent_checks_dir(agent_name).glob("*.py")):
            assert NAME_FILE_PATTERN.match(check_file.name), check_file.name
            assert "\nCHECK_LIST" in check_file.read_text(), check_file.name
