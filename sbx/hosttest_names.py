# --------------------------------------------------------------------------------
# The names the host run uses: run directories, test sandboxes, test root
# --------------------------------------------------------------------------------
# One place for the host run, the integration fixtures and the clean command, so
# a name never drifts between the code that makes a thing and the code that
# finds it again.
# --------------------------------------------------------------------------------

import os
from collections.abc import Mapping
from pathlib import Path


# --------------------------------------------------------------------------------
# Constants
# --------------------------------------------------------------------------------
# The root certificate directory sits outside the run directory prefix on
# purpose: it is reused from run to run, so a clean of the run directories must
# not match it by prefix.
# --------------------------------------------------------------------------------

RUN_DIR_PREFIX = "sbx-hosttest-"
TEST_SANDBOX_PREFIX = "hosttest-"
ROOT_CA_DIR_NAME = "sbx-test-root-ca"
OLD_ROOT_CA_DIR_NAME = "sbx-hosttest-root-ca"
_DEFAULT_TEMP_BASE = "/tmp"


# --------------------------------------------------------------------------------
# Where the run directories live
# --------------------------------------------------------------------------------
# TMPDIR without its trailing slash, else /tmp; Docker Desktop shares it by
# default on macOS.
# --------------------------------------------------------------------------------

def temp_base_dir(environ: Mapping[str, str]) -> Path:
    base_text = environ.get("TMPDIR", "").rstrip("/")

    if not base_text:
        return Path(_DEFAULT_TEMP_BASE)

    return Path(base_text)


# --------------------------------------------------------------------------------
# The test sandboxes
# --------------------------------------------------------------------------------

def shared_sandbox_name(agent: str) -> str:
    return f"{TEST_SANDBOX_PREFIX}{agent}"


# --------------------------------------------------------------------------------
# Whether a mount source is a host-test run directory
# --------------------------------------------------------------------------------
# Docker Desktop may report the temp directory with a /private prefix, so the
# marker is searched for anywhere in the source, for the base as given and as
# resolved. A sandbox of yours that merely shares a name with a test sandbox
# never mounts a directory under the temp base with this prefix.
# --------------------------------------------------------------------------------

def is_run_dir_mount(source: str, base_dir: Path) -> bool:
    for base_text in [str(base_dir), os.path.realpath(base_dir)]:
        marker = f"{base_text.rstrip('/')}/{RUN_DIR_PREFIX}"

        if marker in source:
            return True

    return False
