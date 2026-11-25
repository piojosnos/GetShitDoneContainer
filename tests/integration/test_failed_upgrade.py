# --------------------------------------------------------------------------------
# Scenario: a failed build leaves the running sandbox as it was
# --------------------------------------------------------------------------------
# sbx-upgrade warns first, then builds; when the build fails it must not touch
# the container. A bogus build option makes the build fail at once.
# --------------------------------------------------------------------------------

import io
from pathlib import Path

from scenario_helpers import RunSandbox, inspect_container, run_streamed, step

_UPGRADE_SECONDS = 900


# --------------------------------------------------------------------------------
# test_failed_upgrade_changes_nothing
# --------------------------------------------------------------------------------
# sbx-upgrade NAME --no-such-option -> build fails -> same container, still running
# --------------------------------------------------------------------------------

def test_failed_upgrade_changes_nothing(sandbox: RunSandbox, hosttest_env: dict[str, str], run_dir: Path):
    container = sandbox.container

    with step("record the container"):
        before = inspect_container(container)

        assert before is not None, f"{container} is not there"
        assert before["State"]["Running"] is True, f"{container} is not running"

        id_before = before["Id"]
        start_before = before["State"]["StartedAt"]

    with step("upgrade with a bogus build option"):
        log_file = run_dir / "logs" / f"failed-upgrade-{sandbox.agent.name}.log"
        output = io.StringIO()
        upgrade = run_streamed(
            ["sbx-upgrade", sandbox.name, "--no-such-option"],
            _UPGRADE_SECONDS,
            hosttest_env,
            output,
            log_file,
        )
        warning = (
            f"sbx-upgrade: {container} is running; after the build, recreating it "
            "will close its open shells and Claude sessions"
        )
        failure = f"the build failed; {container} was left as it was"

        assert not upgrade.timed_out, f"sbx-upgrade timed out; log: {log_file}"
        assert upgrade.returncode != 0, f"sbx-upgrade with a bogus build option exited 0; log: {log_file}"
        assert warning in upgrade.stdout, f"the running sandbox got no warning before the build; log: {log_file}"
        assert failure in upgrade.stdout, f"the failed build did not say it left the sandbox alone; log: {log_file}"
        assert upgrade.stdout.index(warning) < upgrade.stdout.index(failure), (
            f"the warning did not come before the failure; log: {log_file}"
        )

    with step("the sandbox is untouched"):
        after = inspect_container(container)

        assert after is not None, f"{container} is gone after the failed build"
        assert after["Id"] == id_before, "the failed build changed the container id"
        assert after["State"]["StartedAt"] == start_before, "the failed build changed the start time"
        assert after["State"]["Running"] is True, f"{container} is not running after the failed build"
