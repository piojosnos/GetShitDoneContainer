# ------------------------------------------------------------------------------
# Shared setup of the sbx unit tests
# ------------------------------------------------------------------------------
# Every test gets its own sbx config directory and registry under tmp_path, and a
# Docker recorder; nothing reaches the user's registry or a Docker daemon.
# ------------------------------------------------------------------------------

from pathlib import Path

import pytest

from sbx_helpers import DockerRecorder


# ------------------------------------------------------------------------------
# Fixtures
# ------------------------------------------------------------------------------

@pytest.fixture
def config_dir(tmp_path) -> Path:
    config1 = tmp_path / "config1"
    config1.mkdir()

    return config1


@pytest.fixture
def registry(config_dir) -> Path:
    registry1 = config_dir / "sandboxes"
    registry1.mkdir()

    return registry1


@pytest.fixture
def recorder() -> DockerRecorder:
    return DockerRecorder()
