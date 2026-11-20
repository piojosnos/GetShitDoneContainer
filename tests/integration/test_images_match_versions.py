# ------------------------------------------------------------------------------
# Scenario: the image carries the versions.env of this checkout
# ------------------------------------------------------------------------------
# A forgotten rebuild leaves an image whose pins differ from the repo's. The
# selfcheck reads the image's own record of the pins, so this is the one place that
# compares that record with the file in the repo.
# ------------------------------------------------------------------------------

import difflib

from agent_specs import AgentSpec
from sbx.names import agent_image
from scenario_helpers import REPO_DIR, describe_result, run_timeout, step

_TEST_TAG = "test"
_RECORD_PATH = "/etc/sbx/versions.env"
_DIFF_LINE_LIMIT = 20


# ------------------------------------------------------------------------------
# The difference, for a failure message
# ------------------------------------------------------------------------------

def _diff_text(record_text: str, repo_text: str, image: str) -> str:
    diff_line_list = list(
        difflib.unified_diff(
            record_text.splitlines(),
            repo_text.splitlines(),
            fromfile=f"{image}:{_RECORD_PATH}",
            tofile="versions.env",
            lineterm="",
        )
    )

    return "\n".join(diff_line_list[:_DIFF_LINE_LIMIT])


# ------------------------------------------------------------------------------
# test_image_versions_match_the_repo
# ------------------------------------------------------------------------------
# /etc/sbx/versions.env in the agent image == versions.env in the repo
# ------------------------------------------------------------------------------

def test_image_versions_match_the_repo(agent: AgentSpec, test_images: None):
    image = agent_image(agent.name, _TEST_TAG)

    with step("the image's record equals the repo's file"):
        record = run_timeout(["docker", "run", "--rm", "--entrypoint", "cat", image, _RECORD_PATH], 120)
        repo_text = (REPO_DIR / "versions.env").read_text(encoding="utf-8")

        assert record.returncode == 0, f"could not read {_RECORD_PATH} in {image}: {describe_result(record)}"
        assert record.stdout == repo_text, (
            f"{_RECORD_PATH} in {image} differs from versions.env; run ./host-test.sh, which rebuilds the test images:\n"
            + _diff_text(record.stdout, repo_text, image)
        )
