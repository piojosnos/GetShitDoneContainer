# ------------------------------------------------------------------------------
# Plain helpers the init tests share
# ------------------------------------------------------------------------------
# The repo folder, step files, stand-in executables, a PATH that puts a folder
# first, step file loading and a runner call.
# ------------------------------------------------------------------------------

from pathlib import Path

REPO_DIR = Path(__file__).resolve().parents[3]
