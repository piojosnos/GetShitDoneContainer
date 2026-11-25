# --------------------------------------------------------------------------------
# Tests of the agent check builder
# --------------------------------------------------------------------------------
# A description made of temp paths shows which field reaches which helper. A
# subprocess loads the real check files with the import path of the launcher.
# --------------------------------------------------------------------------------

import os
import shutil
import subprocess
import sys
from pathlib import Path

import pytest

from agent_checks import agent_check_list
from agent_config import gsd_synced_result
from agent_description import AgentDescription
from best_practices_linker import link_best_practices
from check_result import Check
from helpers import REPO_DIR, agent_lib_dir, agent_checks_dir

AGENT_CHECK_SUFFIX_LIST = [
    "env",
    "home-links",
    "credentials",
    "gsd-synced",
    "best-practices-links",
    "image-root-owned",
    "image-paths-protected",
    "versions-line",
]
LAUNCHER_PATH_CODE = """import sys
from pathlib import Path

sys.dont_write_bytecode = True
sys.path.insert(0, sys.argv[1])
sys.path.append(sys.argv[1] + "/agents")

import runner

for check in runner.dir_check_list(Path(sys.argv[2])):
    print(check.name)
"""


# --------------------------------------------------------------------------------

def test_the_builder_makes_the_eight_checks_named_after_the_agent(tmp_path, check_name_list_of):
    expected_name_list = []

    for suffix in AGENT_CHECK_SUFFIX_LIST:
        expected_name_list.append(f"agent1-{suffix}")

    assert check_name_list_of(agent_check_list(agent1_description(tmp_path))) == expected_name_list


# --------------------------------------------------------------------------------

def test_the_env_check_reads_the_environment_values_of_the_description_from_the_given_map(tmp_path):
    agent1 = agent1_description(tmp_path)
    environment1 = {"SBX_TEST_VAR1": "value1"}

    result = check_named(agent_check_list(agent1, environment_map=environment1), "agent1-env").function()

    assert result.passed
    assert "SBX_TEST_VAR1=value1" in result.detail


# --------------------------------------------------------------------------------

def test_the_home_links_check_walks_every_home_link_of_the_description(tmp_path):
    agent1 = agent1_description(tmp_path)
    link1 = agent1.home_link_list[0]
    link2 = agent1.home_link_list[1]
    agent1.config_dir.mkdir(parents=True)
    link1.parent.mkdir(parents=True)
    os.symlink(str(agent1.config_dir), link1)

    result = check_named(agent_check_list(agent1), "agent1-home-links").function()

    assert not result.passed
    assert result.detail == f"{link2} is not a link"


# --------------------------------------------------------------------------------

def test_the_credentials_check_fails_with_the_login_hint_of_the_description(tmp_path):
    agent1 = agent1_description(tmp_path)

    result = check_named(agent_check_list(agent1), "agent1-credentials").function()

    assert not result.passed
    assert str(agent1.login_file) in result.detail
    assert result.hint == "hint1"


# --------------------------------------------------------------------------------

def test_both_image_checks_walk_the_image_roots_of_the_description(tmp_path):
    agent1 = agent1_description(tmp_path)
    root1 = agent1.image_root_list[0]
    check_list = agent_check_list(agent1)

    owned_result = check_named(check_list, "agent1-image-root-owned").function()
    protected_result = check_named(check_list, "agent1-image-paths-protected").function()

    assert not owned_result.passed
    assert owned_result.detail == f"1 problems: {root1} is missing"
    assert not protected_result.passed
    assert protected_result.detail == f"1 problems: {root1} is missing"


# --------------------------------------------------------------------------------

def test_the_versions_line_check_reads_the_pins_of_the_description(tmp_path):
    result = check_named(agent_check_list(agent1_description(tmp_path)), "agent1-versions-line").function()

    assert not result.passed
    assert result.detail.startswith("SBX_TEST_PIN1 is not in")


# --------------------------------------------------------------------------------

def test_the_gsd_synced_check_reports_on_the_config_dir_of_the_description(tmp_path):
    agent1 = agent1_description(tmp_path)

    result = check_named(agent_check_list(agent1), "agent1-gsd-synced").function()

    assert result == gsd_synced_result(agent1.config_dir)


# --------------------------------------------------------------------------------

def test_the_links_check_reads_the_config_dir_and_name_of_the_description_in_the_given_clone(tmp_path):
    agent1 = agent1_description(tmp_path)
    clone1 = make_clone(tmp_path, "agent1")
    agent1.config_dir.mkdir(parents=True)
    check = check_named(agent_check_list(agent1, best_practices_dir=clone1), "agent1-best-practices-links")

    unlinked_result = check.function()
    link_best_practices(agent1.config_dir, clone1, "agent1")
    linked_result = check.function()

    assert not unlinked_result.passed
    assert linked_result.passed


# --------------------------------------------------------------------------------

@pytest.mark.parametrize("agent_name", ["claude", "cursor"])
def test_the_agent_check_file_loads_with_the_sbx_selfcheck_import_path(
    tmp_path, agent_name, agent_check_list_of, check_name_list_of
):
    lib_dir, agent_dir = copy_selfcheck_layout(tmp_path, agent_name)

    printed_name_list = launcher_path_name_list(lib_dir, agent_dir)

    assert printed_name_list == check_name_list_of(agent_check_list_of(agent_name))

    for printed_name in printed_name_list:
        assert not printed_name.startswith("load-"), printed_name


# --------------------------------------------------------------------------------
# TDL
# --------------------------------------------------------------------------------

def agent1_description(tmp_path: Path) -> AgentDescription:
    config_dir = tmp_path / "state1" / "agent1"

    return AgentDescription(
        name="agent1",
        config_dir=config_dir,
        home_link_list=[tmp_path / "home1" / "link1", tmp_path / "home1" / "link2"],
        login_file=config_dir / "login1.json",
        login_hint="hint1",
        environment_value_by_name_map={"SBX_TEST_VAR1": "value1"},
        image_root_list=[tmp_path / "root1"],
        versions_field_list=[("label1", "SBX_TEST_PIN1")],
        gsd_agent_option="--agent1",
    )


# --------------------------------------------------------------------------------

def make_clone(tmp_path: Path, agent_name: str) -> Path:
    clone_dir = tmp_path / "best-practices"
    generated_dir = clone_dir / "generated" / agent_name
    (generated_dir / "rules").mkdir(parents=True)
    (generated_dir / "rules" / "rule1.md").write_text("rule1\n")
    (generated_dir / "skills" / "skill1").mkdir(parents=True)
    (generated_dir / "skills" / "skill1" / "SKILL.md").write_text("skill1\n")

    return clone_dir


# --------------------------------------------------------------------------------

def check_named(check_list: list[Check], name: str) -> Check:
    for check in check_list:
        if check.name == name:
            return check

    raise AssertionError(f"no check named {name} in the list")


# --------------------------------------------------------------------------------

def copy_selfcheck_layout(tmp_path: Path, agent_name: str) -> tuple[Path, Path]:
    lib_dir = tmp_path / "lib1" / "sbx-selfcheck"
    agents_dir = lib_dir / "agents"
    agent_dir = tmp_path / "etc1" / agent_name
    agents_dir.mkdir(parents=True)
    agent_dir.mkdir(parents=True)

    for module_path in (REPO_DIR / "base" / "selfcheck").glob("*.py"):
        shutil.copy(module_path, lib_dir / module_path.name)

    for module_path in agent_lib_dir(agent_name).glob("*.py"):
        shutil.copy(module_path, agents_dir / module_path.name)

    for check_path in agent_checks_dir(agent_name).glob("*.py"):
        shutil.copy(check_path, agent_dir / check_path.name)

    return lib_dir, agent_dir


# --------------------------------------------------------------------------------

def launcher_path_name_list(lib_dir: Path, agent_dir: Path) -> list[str]:
    completed = subprocess.run(
        [sys.executable, "-I", "-c", LAUNCHER_PATH_CODE, str(lib_dir), str(agent_dir)],
        capture_output=True,
        text=True,
        timeout=60,
        check=False,
    )

    assert completed.returncode == 0, completed.stderr

    return completed.stdout.splitlines()
