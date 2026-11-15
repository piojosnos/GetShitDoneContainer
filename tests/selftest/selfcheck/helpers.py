# ------------------------------------------------------------------------------
# Plain helpers the selfcheck tests share
# ------------------------------------------------------------------------------
# A pins file, a stand-in executable, a PATH that puts a folder first, a
# mountinfo file, a git environment, check file loading, an agent checks file and
# a runner call.
# ------------------------------------------------------------------------------

import io
import os
from pathlib import Path

import runner
from check_result import Check

REPO_DIR = Path(__file__).resolve().parents[3]
SHARED_CHECKS_DIR = REPO_DIR / "base" / "selfcheck" / "checks"
ROOT_MOUNT_LINE = "1 0 8:1 / / rw - ext4 /dev/sda1 rw"
MOUNT_LINE_TEMPLATE = "{number} 1 8:2 / {mount_point} rw,noatime - ext4 /dev/sda2 rw"
TEMURIN_PIN1 = "eclipse-temurin:21.0.12_8-jdk-noble@sha256:abc"
AGENT_FILE_TEMPLATE = """from check_result import Check, passed


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


def load_shared_check(name: str):
    return runner.load_check_module(SHARED_CHECKS_DIR / f"{name}.py")


def agent_checks_dir(agent_name: str) -> Path:
    return REPO_DIR / agent_name / "selfcheck"


def load_agent_check(agent_name: str, name: str):
    return runner.load_check_module(agent_checks_dir(agent_name) / f"{name}.py")


def write_mountinfo(mountinfo_file: Path, mount_point_list: list[str]) -> None:
    line_list = [ROOT_MOUNT_LINE]

    for index, mount_point in enumerate(mount_point_list):
        line_list.append(MOUNT_LINE_TEMPLATE.format(number=index + 2, mount_point=mount_point))

    mountinfo_file.write_text("\n".join(line_list) + "\n")


def write_file(path: Path, text: str = "text1") -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(text)


def git_environment(system_file: Path, global_file: Path) -> dict[str, str]:
    return {
        "PATH": os.environ["PATH"],
        "HOME": str(global_file.parent),
        "GIT_CONFIG_SYSTEM": str(system_file),
        "GIT_CONFIG_GLOBAL": str(global_file),
        "GIT_CONFIG_NOSYSTEM": "1",
    }


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


def run_lines(check_list: list[Check], agent_checks_dir: Path) -> tuple[int, list[str]]:
    output = io.StringIO()
    status = runner.report_checks(check_list + runner.collect_agent_checks(agent_checks_dir), output)

    return status, output.getvalue().splitlines()


def write_agent_file(checks_dir: Path, name: str) -> None:
    checks_dir.mkdir(parents=True, exist_ok=True)
    (checks_dir / f"{name}.py").write_text(AGENT_FILE_TEMPLATE.format(name=name))
