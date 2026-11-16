# ------------------------------------------------------------------------------
# Plain helpers the init tests share
# ------------------------------------------------------------------------------
# The repo folder, step files, stand-in executables, a PATH that puts a folder
# first, step file loading and a runner call.
# ------------------------------------------------------------------------------

import io
import os
from pathlib import Path

import init_runner

REPO_DIR = Path(__file__).resolve().parents[3]
PASSING_STEP_TEMPLATE = """from check_result import Check, passed


def step_{step_name}():
{touch_line}    return passed("detail_{step_name}")


STEP_LIST = [Check("{step_name}", step_{step_name})]
"""
FAILING_STEP_TEMPLATE = """from check_result import Check, failed


def step_{step_name}():
{touch_line}    return failed("detail_{step_name}", "hint_{step_name}")


STEP_LIST = [Check("{step_name}", step_{step_name})]
"""


def write_step_file(
    steps_dir: Path,
    file_stem: str,
    step_name: str,
    passes: bool = True,
    touch_file: Path | None = None,
) -> Path:
    steps_dir.mkdir(parents=True, exist_ok=True)
    touch_line = ""

    if touch_file is not None:
        touch_line = f"    open({str(touch_file)!r}, 'w').close()\n"

    template = PASSING_STEP_TEMPLATE

    if not passes:
        template = FAILING_STEP_TEMPLATE

    step_path = steps_dir / f"{file_stem}.py"
    step_path.write_text(template.format(step_name=step_name, touch_line=touch_line))

    return step_path


def write_stand_in(folder: Path, name: str, script_body: str) -> Path:
    stand_in = folder / name
    stand_in.write_text("#!/bin/sh\n" + script_body + "\n")
    stand_in.chmod(0o755)

    return stand_in


def environment_with(folder: Path) -> dict[str, str]:
    return {"PATH": f"{folder}{os.pathsep}{os.environ['PATH']}"}


def load_step(path: Path):
    return init_runner.load_step_module(path)


def run_lines(
    shared_steps_dir: Path,
    agent_steps_dir: Path,
    marker_file: Path,
    lock_file: Path,
) -> tuple[int, list[str]]:
    output = io.StringIO()
    status = init_runner.run_init(shared_steps_dir, agent_steps_dir, marker_file, lock_file, output)

    return status, output.getvalue().splitlines()
