# ------------------------------------------------------------------------------
# Tests of the init step inventory
# ------------------------------------------------------------------------------
# They pin the merged step order of each image, the file and step name rules and
# the Dockerfile lines that copy the steps into the image. The steps load
# through the runner's own collector.
# ------------------------------------------------------------------------------

import re
import shutil
from pathlib import Path

import pytest

import init_runner
import paths
from init_helpers import REPO_DIR

NAME_PATTERN = re.compile(r"^[a-z0-9]+(-[a-z0-9]+)*$")
NAME_FILE_PATTERN = re.compile(r"^[0-9]{3}_[a-z0-9_]+\.py$")
SHARED_STEPS_DIR = REPO_DIR / "base" / "init" / "steps"
STEP_ORDER_BY_AGENT_MAP = {
    "claude": ["state-folders", "claude-gsd-sync", "state-owner", "claude-best-practices-links"],
    "cursor": [
        "state-folders",
        "cursor-gsd-sync",
        "cursor-self-update-off",
        "state-owner",
        "cursor-best-practices-links",
    ],
}
BASE_DOCKERFILE_LINE_LIST = [
    "COPY --chmod=755 base/init/sbx-init /usr/local/lib/sbx-init/sbx-init",
    "COPY --chmod=644 base/init/*.py /usr/local/lib/sbx-init/",
    "COPY --chmod=644 base/init/steps/*.py /usr/local/lib/sbx-init/steps/",
    "ln -s /usr/local/lib/sbx-init/sbx-init /usr/local/bin/sbx-init",
]


# ------------------------------------------------------------------------------
# Helpers
# ------------------------------------------------------------------------------

def agent_step_file_list(agent_name: str) -> list[Path]:
    return sorted((REPO_DIR / agent_name / "init").glob("*.py"))


def all_step_file_list() -> list[Path]:
    step_file_list = sorted(SHARED_STEPS_DIR.glob("*.py"))

    for agent_name in STEP_ORDER_BY_AGENT_MAP:
        step_file_list.extend(agent_step_file_list(agent_name))

    return step_file_list


def collected_name_list(tmp_path: Path, agent_name: str) -> list[str]:
    agents1 = tmp_path / "agents1"
    shutil.copytree(REPO_DIR / agent_name / "init", agents1 / agent_name)

    return [step.name for step in init_runner.collect_steps(SHARED_STEPS_DIR, agents1)]


def dockerfile_text(folder_name: str) -> str:
    return (REPO_DIR / folder_name / "Dockerfile").read_text()


# ------------------------------------------------------------------------------
# Order and names
# ------------------------------------------------------------------------------

@pytest.mark.parametrize("agent_name", ["claude", "cursor"])
def test_the_merged_steps_of_an_image_run_in_the_fixed_order(tmp_path, agent_name):
    assert collected_name_list(tmp_path, agent_name) == STEP_ORDER_BY_AGENT_MAP[agent_name]


@pytest.mark.parametrize("agent_name", ["claude", "cursor"])
def test_no_step_of_an_image_is_a_load_failure(tmp_path, agent_name):
    for name in collected_name_list(tmp_path, agent_name):
        assert not name.startswith("load-")


def test_every_step_file_name_has_a_three_digit_order_prefix():
    for step_file in all_step_file_list():
        assert NAME_FILE_PATTERN.match(step_file.name), step_file


def test_every_step_file_defines_a_step_list():
    for step_file in all_step_file_list():
        line_list = step_file.read_text().splitlines()
        has_step_list = False

        for line in line_list:
            if line.startswith("STEP_LIST"):
                has_step_list = True

        assert has_step_list, step_file


@pytest.mark.parametrize("agent_name", ["claude", "cursor"])
def test_no_three_digit_prefix_repeats_within_one_image(agent_name):
    prefix_list = []

    for step_file in sorted(SHARED_STEPS_DIR.glob("*.py")) + agent_step_file_list(agent_name):
        prefix_list.append(step_file.name[:3])

    assert len(prefix_list) == len(set(prefix_list))


@pytest.mark.parametrize("agent_name", ["claude", "cursor"])
def test_every_step_name_is_well_formed(tmp_path, agent_name):
    for name in collected_name_list(tmp_path, agent_name):
        assert NAME_PATTERN.match(name), name


# ------------------------------------------------------------------------------
# Where the image keeps the steps
# ------------------------------------------------------------------------------

def test_the_base_dockerfile_installs_sbx_init_and_has_no_entrypoint():
    text = dockerfile_text("base")

    for line in BASE_DOCKERFILE_LINE_LIST:
        assert line in text

    assert "mkdir -p /usr/local/lib/sbx-init/steps /etc/sbx/init.d /opt/sbx/agents/bin" in text
    assert "ENTRYPOINT" not in text
    assert "sbx-entrypoint" not in text


def test_the_shared_step_file_module_reaches_the_image_and_sbx_init_can_import_it():
    base_text = dockerfile_text("base")

    assert (REPO_DIR / "base" / "selfcheck" / "step_files.py").is_file()
    assert "COPY --chmod=644 base/selfcheck/*.py /usr/local/lib/sbx-selfcheck/" in base_text
    assert "python3 -m py_compile" in base_text
    assert "/usr/local/lib/sbx-selfcheck/*.py" in base_text


@pytest.mark.parametrize("agent_name", ["claude", "cursor"])
def test_each_agent_dockerfile_copies_its_own_steps_and_names_no_start_hooks(agent_name):
    text = dockerfile_text(agent_name)

    assert f"COPY --chmod=644 {agent_name}/init/*.py {paths.AGENT_STEPS_DIR}/{agent_name}/" in text
    assert "start.d" not in text


def test_compose_keeps_the_container_running_with_tini_and_no_entrypoint():
    text = (REPO_DIR / "compose.yml").read_text()
    code_line_list = []

    for line in text.splitlines():
        code_line_list.append(line.split("#")[0].strip())

    assert "init: true" in code_line_list
    assert 'command: ["sleep", "infinity"]' in code_line_list

    for code_line in code_line_list:
        assert not code_line.startswith("entrypoint:")
