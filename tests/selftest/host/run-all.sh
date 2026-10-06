#!/usr/bin/env bash
# Self-test for the host tests: runs them on Linux against the fake docker in support/fake-docker, group by group, and prints one summary.
# - Proves the parsing, the PASS/FAIL lines, the run order, the exit codes and the printed
#   text of tests/host/lib.sh, tests/host/run-all.sh and every check.
# - Cannot prove Docker behavior. The real proof is: bash tests/host/run-all.sh on the Mac.
# - The fake docker logs every call; the cases read that log to prove no real sandbox name
#   and nothing destructive reaches docker.
# - Each group makes one work folder under TMPDIR and removes only that folder at exit.
# - Linux only, in the dev sandbox.
# - Usage, from anywhere: bash tests/selftest/host/run-all.sh   (exit 0 = every case passes)
set -u
. "$(dirname "$0")/../lib-expect.sh"

# --------------------------------------------------------------------------------
# Group programs, in run order
# --------------------------------------------------------------------------------
groupList="units.sh runner-healthy.sh h00-compose-v2.sh h02-claude-on-base.sh h03-variable-interpolation.sh h04-nonroot-user.sh h12-plain-run-refused-pin-installed.sh h01-native-arch.sh h05-workspace-and-home.sh h13-env-and-no-self-update.sh h06-git-and-identity.sh h08-history-survives-recreate.sh h14-bundle-in-image.sh h16-sync-refreshes-and-spares.sh h15-bundle-synced-and-visible.sh h11-stop-is-quick-and-safe.sh h09-rebuild-keeps-files-no-volumes.sh h10-missing-folder-refused.sh"

# --------------------------------------------------------------------------------
# Main / Entry Point
# --------------------------------------------------------------------------------
require_no_arguments "$@" || exit 2
run_groups "$(dirname "$0")" $groupList
report_and_exit
