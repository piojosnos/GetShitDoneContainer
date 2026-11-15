# ------------------------------------------------------------------------------
# Tests of the Cursor image paths checks
# ------------------------------------------------------------------------------

from pathlib import Path

import cursor_shared
from helpers import load_agent_check

image_paths_protected = load_agent_check("cursor", "110_image_paths_protected")
wrappers = load_agent_check("cursor", "100_wrappers")


# ------------------------------------------------------------------------------
# Cursor image roots
# ------------------------------------------------------------------------------

def test_the_image_root_is_the_folder_the_image_installs_the_agent_in():
    assert cursor_shared.IMAGE_ROOT_LIST == [Path("/usr/local/lib/cursor-agent")]


def test_the_ownership_check_and_the_protected_paths_check_share_the_one_roots_list():
    assert wrappers.IMAGE_ROOT_LIST is cursor_shared.IMAGE_ROOT_LIST
    assert image_paths_protected.IMAGE_ROOT_LIST is cursor_shared.IMAGE_ROOT_LIST
