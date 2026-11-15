# ------------------------------------------------------------------------------
# Tests of the image paths protected check
# ------------------------------------------------------------------------------

from pathlib import Path

from helpers import load_shared_check

image_paths_protected = load_shared_check("260_image_paths_protected")


# ------------------------------------------------------------------------------
# Image paths protected
# ------------------------------------------------------------------------------

def test_the_check_protects_the_config_the_scripts_and_the_selfcheck_folder():
    assert image_paths_protected._PROTECTED_PATH_LIST == [
        Path("/etc/sbx"),
        Path("/usr/local/bin"),
        Path("/usr/local/lib/sbx-selfcheck"),
    ]
