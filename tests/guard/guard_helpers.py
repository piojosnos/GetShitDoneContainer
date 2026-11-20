# ------------------------------------------------------------------------------
# Helpers the guard rules share: file lists, the line search, the linter runner
# ------------------------------------------------------------------------------
# The guard reads files only. Each file list is a glob evaluated when a rule
# runs, so a file another change deletes drops out of its list by itself.
# tests/guard/ is in no list: its rule files name the strings they forbid.
# ------------------------------------------------------------------------------

import re
import shutil
import subprocess
from pathlib import Path

REPO_DIR = Path(__file__).resolve().parents[2]

_LINTER_IMAGE = "sbx-base:test"
_LAUNCHER_SHEBANG = "#!/bin/sh"
_ROOT_SCRIPT_NAME_LIST = ["build.sh", "clean.sh", "host-test.sh"]


# ------------------------------------------------------------------------------
# File lists
# ------------------------------------------------------------------------------

def _glob_list(pattern: str) -> list[Path]:
    file_list = []

    for path in sorted(REPO_DIR.glob(pattern)):
        if path.is_file():
            file_list.append(path)

    return file_list


def _first_line(path: Path) -> str:
    with open(path, encoding="utf-8", errors="replace") as handle:
        return handle.readline().rstrip("\n")


def dockerfile_list() -> list[Path]:
    return _glob_list("base/Dockerfile") + _glob_list("claude/Dockerfile") + _glob_list("cursor/Dockerfile")


def compose_file() -> Path:
    return REPO_DIR / "compose.yml"


def launcher_list() -> list[Path]:
    launcher_file_list = _glob_list("bin/*")

    for name in _ROOT_SCRIPT_NAME_LIST:
        path = REPO_DIR / name

        if path.is_file() and _first_line(path) == _LAUNCHER_SHEBANG:
            launcher_file_list.append(path)

    return launcher_file_list


def image_script_list() -> list[Path]:
    return _glob_list("base/bin/*") + _glob_list("claude/bin/*") + _glob_list("cursor/bin/*")


def shell_file_list() -> list[Path]:
    shell_list = []

    for name in _ROOT_SCRIPT_NAME_LIST:
        shell_list += _glob_list(name)

    shell_list += _glob_list("bin/*")
    shell_list += image_script_list()
    shell_list += _glob_list("tests/**/*.sh")

    return shell_list


def host_python_list() -> list[Path]:
    return _glob_list("sbx/*.py")


def test_python_list() -> list[Path]:
    python_list = []

    for path in _glob_list("tests/**/*.py"):
        if (REPO_DIR / "tests" / "guard") in path.parents:
            continue

        python_list.append(path)

    return python_list


# The name starts with test_ only because it names the list of test files; the
# marker keeps pytest from collecting it as a test when a rule file imports it.
test_python_list.__test__ = False


def sandbox_file_list() -> list[Path]:
    sandbox_list = dockerfile_list()
    sandbox_list += _glob_list("compose.yml")
    sandbox_list += _glob_list("versions.env")
    sandbox_list += _glob_list("bin/*")
    sandbox_list += _glob_list("build.sh")
    sandbox_list += _glob_list("clean.sh")
    sandbox_list += host_python_list()

    return sandbox_list


def relative_name(path: Path) -> str:
    return str(path.relative_to(REPO_DIR))


def relative_name_list(path_list: list[Path]) -> list[str]:
    name_list = []

    for path in path_list:
        name_list.append(relative_name(path))

    return name_list


# ------------------------------------------------------------------------------
# nowhere_matches PATTERN PATH_LIST: the lines that match, as hits; none is a pass
# ------------------------------------------------------------------------------
# An empty list is an error, so a rule never passes by scanning nothing. A file
# that cannot be read is a hit.
# ------------------------------------------------------------------------------

def nowhere_matches(pattern: str, path_list: list[Path]) -> list[str]:
    if not path_list:
        raise AssertionError("no file to scan")

    compiled = re.compile(pattern)
    hit_list = []

    for path in path_list:
        try:
            text = path.read_text(encoding="utf-8", errors="replace")
        except OSError:
            hit_list.append(f"{relative_name(path)}: could not be read")
            continue

        line_number = 0

        for line in text.splitlines():
            line_number += 1

            if compiled.search(line):
                hit_list.append(f"{relative_name(path)}:{line_number}: {line}")

    return hit_list


# ------------------------------------------------------------------------------
# run_linter TOOL ARGUMENT_LIST: runs a linter here, else from the test base image
# ------------------------------------------------------------------------------
# The host needs neither shellcheck nor hadolint: the test base image ships both,
# and the repo is mounted read-only. Returns the exit status and the output.
# ------------------------------------------------------------------------------

def run_linter(tool: str, argument_list: list[str]) -> tuple[int, str]:
    if shutil.which(tool):
        return _run([tool, *argument_list])

    if _test_image_exists():
        repo = str(REPO_DIR)

        return _run([
            "docker", "run", "--rm",
            "-v", f"{repo}:{repo}:ro",
            "-w", repo,
            "--entrypoint", tool,
            _LINTER_IMAGE,
            *argument_list,
        ])

    return 1, f"{tool} is not installed here and {_LINTER_IMAGE} is missing; ./host-test.sh builds it"


def _test_image_exists() -> bool:
    if not shutil.which("docker"):
        return False

    status, _ = _run(["docker", "image", "inspect", _LINTER_IMAGE])

    return status == 0


def _run(command_list: list[str]) -> tuple[int, str]:
    completed = subprocess.run(
        command_list,
        cwd=REPO_DIR,
        capture_output=True,
        text=True,
        check=False,
    )

    return completed.returncode, completed.stdout + completed.stderr
