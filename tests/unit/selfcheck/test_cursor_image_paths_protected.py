# ------------------------------------------------------------------------------
# Tests of the Cursor image paths checks
# ------------------------------------------------------------------------------

from pathlib import Path

import cursor_shared
from helpers import load_agent_check

image_paths_protected = load_agent_check("cursor", "110_image_paths_protected")
image_root_owned = load_agent_check("cursor", "100_image_root_owned")


# ------------------------------------------------------------------------------
# Cursor image roots
# ------------------------------------------------------------------------------

def test_the_image_root_is_the_dir_the_image_installs_the_agent_in():
    assert cursor_shared.IMAGE_ROOT_LIST == [Path("/usr/local/lib/cursor-agent")]


def test_the_ownership_check_and_the_protected_paths_check_share_the_one_roots_list():
    assert image_root_owned.IMAGE_ROOT_LIST is cursor_shared.IMAGE_ROOT_LIST
    assert image_paths_protected.IMAGE_ROOT_LIST is cursor_shared.IMAGE_ROOT_LIST
