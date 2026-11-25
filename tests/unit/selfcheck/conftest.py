# --------------------------------------------------------------------------------
# Shared setup of the sbx-selfcheck tests
# --------------------------------------------------------------------------------
# The base selfcheck directory reaches sys.path through the pytest pythonpath
# setting in pyproject.toml, the way the launcher puts it there.
# --------------------------------------------------------------------------------

import subprocess
from pathlib import Path

import pytest

import runner
from helpers import REPO_DIR, SHARED_CHECKS_DIR, agent_checks_dir, write_agent_file, write_versions


# --------------------------------------------------------------------------------
# Fixtures
# --------------------------------------------------------------------------------

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


@pytest.fixture
def restorable_mode():
    restore_list = []

    def lower_mode(path: Path, mode: int) -> None:
        restore_list.append((path, path.stat().st_mode))
        path.chmod(mode)

    yield lower_mode

    for path, mode in reversed(restore_list):
        path.chmod(mode)


@pytest.fixture
def check_name_list_of():
    def names_of(check_list: list) -> list[str]:
        name_list = []

        for check in check_list:
            name_list.append(check.name)

        return name_list

    return names_of


@pytest.fixture
def shared_check_list():
    return runner.dir_check_list(SHARED_CHECKS_DIR)


@pytest.fixture
def agent_check_list_of():
    def check_list_of(agent_name: str) -> list:
        return runner.dir_check_list(agent_checks_dir(agent_name))

    return check_list_of


@pytest.fixture
def versions1(tmp_path) -> Path:
    return write_versions(tmp_path / "versions1.env")


@pytest.fixture
def bin1(tmp_path) -> Path:
    bin_dir = tmp_path / "bin1"
    bin_dir.mkdir()

    return bin_dir


@pytest.fixture
def line1(tmp_path) -> Path:
    return tmp_path / "line1"


@pytest.fixture
def shared1(tmp_path) -> Path:
    shared_dir = tmp_path / "shared1"
    shared_dir.mkdir()
    write_agent_file(shared_dir, "check1")

    return shared_dir


@pytest.fixture
def agents1(tmp_path) -> Path:
    agents_dir = tmp_path / "agents1"
    (agents_dir / "group1").mkdir(parents=True)
    write_agent_file(agents_dir / "group1", "agent1")

    return agents_dir


@pytest.fixture
def group1(tmp_path) -> Path:
    group_dir = tmp_path / "group1"
    group_dir.mkdir()

    return group_dir
