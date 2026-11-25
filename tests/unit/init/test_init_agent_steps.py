# --------------------------------------------------------------------------------
# Tests of the agent step builders
# --------------------------------------------------------------------------------
# A temp-path description and a recording sync function show which field reaches
# which call. A subprocess loads the real step files with the import path of the
# launcher.
# --------------------------------------------------------------------------------

import shutil
import subprocess
import sys
from pathlib import Path

import pytest

import init_runner
from agent_description import AgentDescription
from agent_steps import best_practices_links_step_list, gsd_sync_step_list
from init_helpers import REPO_DIR

SHARED_STEPS_DIR = REPO_DIR / "base" / "init" / "steps"
LAUNCHER_PATH_CODE = """import sys
from pathlib import Path

sys.dont_write_bytecode = True
sys.path.insert(0, sys.argv[1])
sys.path.append(sys.argv[2])
sys.path.append(sys.argv[2] + "/agents")

import init_runner

for step in init_runner.collect_steps(Path(sys.argv[1]) / "steps", Path(sys.argv[3])):
    print(step.name)
"""


# --------------------------------------------------------------------------------

def test_the_gsd_sync_step_syncs_the_config_dir_with_the_agent_option_of_the_description(tmp_path):
    agent1 = agent1_description(tmp_path)
    call_list = []

    def record_call(config_dir, agent_option):
        call_list.append((config_dir, agent_option))

        return "recorded"

    step_list = gsd_sync_step_list(agent1, record_call)

    assert [step.name for step in step_list] == ["agent1-gsd-sync"]
    assert step_list[0].function() == "recorded"
    assert call_list == [(agent1.config_dir, "--agent1")]


# --------------------------------------------------------------------------------

def test_the_best_practices_links_step_links_the_config_dir_for_the_name_of_the_description(tmp_path):
    agent1 = agent1_description(tmp_path)
    clone1 = make_clone(tmp_path, "agent1")
    agent1.config_dir.mkdir(parents=True)

    step_list = best_practices_links_step_list(agent1, best_practices_dir=clone1)
    result = step_list[0].function()

    assert [step.name for step in step_list] == ["agent1-best-practices-links"]
    assert result.passed
    assert (agent1.config_dir / "rules").resolve() == clone1 / "generated" / "agent1" / "rules"
    assert (agent1.config_dir / "skills" / "skill1").is_symlink()


# --------------------------------------------------------------------------------

@pytest.mark.parametrize("agent_name", ["claude", "cursor"])
def test_the_agent_step_files_load_with_the_sbx_init_import_path(tmp_path, agent_name):
    init_dir, selfcheck_dir, agent_steps_dir = copy_init_layout(tmp_path, agent_name)

    printed_name_list = launcher_path_name_list(init_dir, selfcheck_dir, agent_steps_dir)

    expected_name_list = []

    for step in init_runner.collect_steps(SHARED_STEPS_DIR, agent_steps_dir):
        expected_name_list.append(step.name)

    assert printed_name_list == expected_name_list

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
        home_link_list=[tmp_path / "home1" / "link1"],
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

def copy_init_layout(tmp_path: Path, agent_name: str) -> tuple[Path, Path, Path]:
    init_dir = tmp_path / "lib1" / "sbx-init"
    selfcheck_dir = tmp_path / "lib1" / "sbx-selfcheck"
    agent_steps_dir = tmp_path / "agents1" / agent_name
    (init_dir / "steps").mkdir(parents=True)
    (selfcheck_dir / "agents").mkdir(parents=True)
    agent_steps_dir.mkdir(parents=True)

    for module_path in (REPO_DIR / "base" / "init").glob("*.py"):
        shutil.copy(module_path, init_dir / module_path.name)

    for step_path in SHARED_STEPS_DIR.glob("*.py"):
        shutil.copy(step_path, init_dir / "steps" / step_path.name)

    for module_path in (REPO_DIR / "base" / "selfcheck").glob("*.py"):
        shutil.copy(module_path, selfcheck_dir / module_path.name)

    for module_path in (REPO_DIR / agent_name / "selfcheck" / "lib").glob("*.py"):
        shutil.copy(module_path, selfcheck_dir / "agents" / module_path.name)

    for step_path in (REPO_DIR / agent_name / "init").glob("*.py"):
        shutil.copy(step_path, agent_steps_dir / step_path.name)

    return init_dir, selfcheck_dir, tmp_path / "agents1"


# --------------------------------------------------------------------------------

def launcher_path_name_list(init_dir: Path, selfcheck_dir: Path, agent_steps_dir: Path) -> list[str]:
    completed = subprocess.run(
        [sys.executable, "-I", "-c", LAUNCHER_PATH_CODE, str(init_dir), str(selfcheck_dir), str(agent_steps_dir)],
        capture_output=True,
        text=True,
        timeout=60,
        check=False,
    )

    assert completed.returncode == 0, completed.stderr

    return completed.stdout.splitlines()
