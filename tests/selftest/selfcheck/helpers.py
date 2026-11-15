# ------------------------------------------------------------------------------
# Plain helpers the selfcheck tests share
# ------------------------------------------------------------------------------
# A pins file, a stand-in executable and a PATH that puts a folder first.
# ------------------------------------------------------------------------------

import os
from pathlib import Path

TEMURIN_PIN1 = "eclipse-temurin:21.0.12_8-jdk-noble@sha256:abc"


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
