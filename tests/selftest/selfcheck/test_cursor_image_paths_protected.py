# ------------------------------------------------------------------------------
# Tests of the Cursor image paths protected check
# ------------------------------------------------------------------------------

from pathlib import Path

from helpers import load_agent_check

image_paths_protected = load_agent_check("cursor", "110_image_paths_protected")


# ------------------------------------------------------------------------------
# Cursor image paths protected
# ------------------------------------------------------------------------------

def test_the_check_protects_the_folder_the_image_installs_the_agent_in():
    assert image_paths_protected._PROTECTED_PATH_LIST == [Path("/usr/local/lib/cursor-agent")]
