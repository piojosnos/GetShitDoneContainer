# ------------------------------------------------------------------------------
# Scenario: sbx-upgrade of a running sandbox
# ------------------------------------------------------------------------------
# The one successful upgrade of a sandbox that is running: the warning comes before
# the build, the container is recreated on the current image, and the run ends with
# its three closing lines. The recreate removes the init marker; the next scenario's
# sandbox fixture runs sbx-init again.
# ------------------------------------------------------------------------------

import io
from pathlib import Path

from sbx import build
from sbx.names import agent_image
from scenario_helpers import (
    RunSandbox,
    describe_result,
    docker_exec,
    inspect_container,
    run_streamed,
    run_timeout,
    step,
)

_UPGRADE_SECONDS = 1800
_TEST_TAG = "test"
_CLOSING_LINE_COUNT = 3


# ------------------------------------------------------------------------------
# The id of an image
# ------------------------------------------------------------------------------
# An image Docker does not know has the empty id, so a caller asserts on it.
# ------------------------------------------------------------------------------

def _image_id(image: str) -> str:
    result = run_timeout(["docker", "image", "inspect", "--format", "{{.Id}}", image], 60)

    if result.returncode != 0:
        return ""

    return result.stdout.strip()


# ------------------------------------------------------------------------------
# test_upgrade_of_a_running_sandbox
# ------------------------------------------------------------------------------
# sbx-upgrade NAME on a running sandbox -> warning, build, recreate -> closing lines
# ------------------------------------------------------------------------------

def test_upgrade_of_a_running_sandbox(sandbox: RunSandbox, hosttest_env: dict[str, str], run_dir: Path):
    container = sandbox.container
    image = agent_image(sandbox.agent.name, _TEST_TAG)

    with step("record the running container"):
        before = inspect_container(container)

        assert before is not None, f"{container} is not there"
        assert before["State"]["Running"] is True, f"{container} is not running"

        id_before = before["Id"]

    with step("upgrade the running sandbox"):
        log_file = run_dir / "logs" / f"running-upgrade-{sandbox.agent.name}.log"
        output = io.StringIO()
        upgrade = run_streamed(["sbx-upgrade", sandbox.name], _UPGRADE_SECONDS, hosttest_env, output, log_file)
        warning = (
            f"sbx-upgrade: {container} is running; after the build, recreating it "
            "will close its open shells and Claude sessions"
        )
        build_start = f"{build.COMMAND_NAME}: building "

        assert not upgrade.timed_out, f"sbx-upgrade timed out; log: {log_file}"
        assert upgrade.returncode == 0, f"sbx-upgrade exited {upgrade.returncode}; log: {log_file}"
        assert warning in upgrade.stdout, f"the running sandbox got no warning; log: {log_file}"
        assert build_start in upgrade.stdout, f"the output shows no build start; log: {log_file}"
        assert upgrade.stdout.index(warning) < upgrade.stdout.index(build_start), (
            f"the warning did not come before the build started; log: {log_file}"
        )

    with step("the container is recreated on the current image"):
        after = inspect_container(container)
        image_id = _image_id(image)

        assert image_id, f"the image {image} is not there after sbx-upgrade"
        assert after is not None, f"{container} is not there after sbx-upgrade"
        assert after["Id"] != id_before, "sbx-upgrade did not recreate the container"
        assert after["State"]["Running"] is True, f"{container} is not running after sbx-upgrade"
        assert after["Image"] == image_id, (
            f"{container} runs on image {after['Image']}, the current {image} is {image_id}"
        )

    with step("the run ends with the marker line, the images line and the tool versions"):
        versions = docker_exec(container, "cat /etc/sbx/tool-versions")
        closing_list = upgrade.stdout.strip().splitlines()[-_CLOSING_LINE_COUNT:]

        assert versions.returncode == 0, describe_result(versions)
        assert closing_list == [
            "sbx-upgrade: the recreate removed the init marker; run sbx-init in the sandbox shell before the agent",
            f"sbx-upgrade: {container} runs on the new images",
            versions.stdout.strip(),
        ], f"the last lines are not the closing lines; log: {log_file}"
