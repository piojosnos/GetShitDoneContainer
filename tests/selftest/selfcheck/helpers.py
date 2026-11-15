# ------------------------------------------------------------------------------
# Plain helpers the selfcheck tests share
# ------------------------------------------------------------------------------
# A pins file, a stand-in executable, a PATH that puts a folder first, an agent
# checks file and a runner call.
# ------------------------------------------------------------------------------

import io
import os
from pathlib import Path

import sbx_selfcheck
from selfcheck_core import Check

TEMURIN_PIN1 = "eclipse-temurin:21.0.12_8-jdk-noble@sha256:abc"
AGENT_FILE_TEMPLATE = """from selfcheck_core import Check, passed


def check_{name}():
    return passed("detail_{name}")


CHECK_LIST = [Check("{name}", check_{name})]
"""


def write_stand_in(folder: Path, name: str, script_body: str) -> Path:
    stand_in = folder / name
    stand_in.write_text("#!/bin/sh\n" + script_body + "\n")
    stand_in.chmod(0o755)

    return stand_in


def environment_with(folder: Path) -> dict[str, str]:
    return {"PATH": f"{folder}{os.pathsep}{os.environ['PATH']}"}


def write_versions(versions_file: Path, extra_line_list: list[str] | None = None) -> Path:
    line_list = [
        "GH_VERSION=2.102.0",
        "NODE_VERSION=24.21.0",
        "MAVEN_VERSION=3.9.11",
        "GSD_CORE_VERSION=1.15.0",
        f"TEMURIN_IMAGE={TEMURIN_PIN1}",
        "UV_IMAGE=ghcr.io/astral-sh/uv:0.12.21@sha256:abc",
        "BUNDLE_REPO_URL=https://example.test/repo1.git",
    ]

    if extra_line_list:
        line_list.extend(extra_line_list)

    versions_file.write_text("\n".join(line_list) + "\n")

    return versions_file


def run_lines(shared_check_list: list[Check], checks_dir: Path) -> tuple[int, list[str]]:
    output = io.StringIO()
    status = sbx_selfcheck.run_selfcheck(shared_check_list, checks_dir, output)

    return status, output.getvalue().splitlines()


def write_agent_file(checks_dir: Path, name: str) -> None:
    (checks_dir / f"{name}.py").write_text(AGENT_FILE_TEMPLATE.format(name=name))
