#!/usr/bin/env bash
# Self-test of the best-practices bundle: runs every group below and prints one summary.
# - Proves the start hook claude/start.d/10-best-practices on fixtures and on the real bundle.
# - Proves that Claude Code at the pinned version sees the synced bundle (offline, no login).
# - Cannot prove Docker. The real proof is: bash tests/host/run-all.sh on the Mac.
# - Each group makes its own work folder under TMPDIR and removes only that folder at exit.
# - Linux only, in the dev sandbox.
# - Usage, from anywhere: bash tests/selftest/bundle/run-all.sh   (exit 0 = every case passes)
set -u
. "$(dirname "$0")/../lib-expect.sh"

# --------------------------------------------------------------------------------
# Group programs, in run order
# --------------------------------------------------------------------------------
groupList="real-bundle.sh skill-lists.sh failures.sh refresh.sh user-files.sh claude-probe.sh fake-api.sh"

# --------------------------------------------------------------------------------
# Main / Entry Point
# --------------------------------------------------------------------------------
require_no_arguments "$@" || exit 2
run_groups "$(dirname "$0")" $groupList
report_and_exit
