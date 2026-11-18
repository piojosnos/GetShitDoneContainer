# ------------------------------------------------------------------------------
# Tests of the Claude image paths checks
# ------------------------------------------------------------------------------

from pathlib import Path

import claude_shared
from helpers import load_agent_check

image_paths_protected = load_agent_check("claude", "110_image_paths_protected")
image_root_owned = load_agent_check("claude", "100_image_root_owned")


# ------------------------------------------------------------------------------
# Claude image roots
# ------------------------------------------------------------------------------

def test_the_image_root_is_the_dir_the_image_installs_the_agent_in():
    assert claude_shared.IMAGE_ROOT_LIST == [Path("/etc/claude-code")]


def test_the_ownership_check_and_the_protected_paths_check_share_the_one_roots_list():
    assert image_root_owned.IMAGE_ROOT_LIST is claude_shared.IMAGE_ROOT_LIST
    assert image_paths_protected.IMAGE_ROOT_LIST is claude_shared.IMAGE_ROOT_LIST
