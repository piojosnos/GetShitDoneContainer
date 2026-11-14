# Shared setup of the sbx-selfcheck tests. Bytecode stays off before any repo
# module is imported, so the source folders get no __pycache__; the base
# selfcheck folder goes on sys.path the way the launcher puts it there.

import sys
from pathlib import Path

import pytest

sys.dont_write_bytecode = True

REPO_DIR = Path(__file__).resolve().parents[3]

sys.path.insert(0, str(REPO_DIR / "base" / "selfcheck"))


@pytest.fixture
def repo_dir() -> Path:
    return REPO_DIR
