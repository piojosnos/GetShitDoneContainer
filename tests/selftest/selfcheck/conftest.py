# Shared setup of the sbx-selfcheck tests. Bytecode stays off before any repo
# module is imported, so the source folders get no __pycache__; the base
# selfcheck folder goes on sys.path the way the launcher puts it there.

import subprocess
import sys
from pathlib import Path

import pytest

sys.dont_write_bytecode = True

REPO_DIR = Path(__file__).resolve().parents[3]

sys.path.insert(0, str(REPO_DIR / "base" / "selfcheck"))


@pytest.fixture
def repo_dir() -> Path:
    return REPO_DIR


@pytest.fixture
def make_certificate(tmp_path):
    def new_certificate(name: str) -> Path:
        certificate_file = tmp_path / f"{name}.pem"
        key_file = tmp_path / f"{name}.key"

        subprocess.run(
            [
                "openssl", "req", "-x509", "-newkey", "ec", "-pkeyopt", "ec_paramgen_curve:prime256v1",
                "-nodes", "-days", "1", "-subj", f"/CN={name}", "-keyout", str(key_file), "-out", str(certificate_file),
            ],
            check=True,
            capture_output=True,
        )
        key_file.unlink()

        return certificate_file

    return new_certificate
