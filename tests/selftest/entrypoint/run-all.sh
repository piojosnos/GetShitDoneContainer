#!/usr/bin/env bash
# Self-test of the container start: runs every group below and prints one summary.
# - Sources base/sbx-start-lib.sh in a subshell, so no mount and no Docker are needed.
# - Checks that the library runs nothing when sourced and that base/sbx-entrypoint runs the start checks.
# - Each group makes its own work folder under TMPDIR and removes only that folder at exit.
# - Linux only, in the dev sandbox.
# - Usage, from anywhere: bash tests/selftest/entrypoint/run-all.sh   (exit 0 = every case passes)
set -u
. "$(dirname "$0")/../lib-expect.sh"

# --------------------------------------------------------------------------------
# Group programs, in run order
# --------------------------------------------------------------------------------
groupList="start-hooks.sh start-library.sh start-folders.sh"

# --------------------------------------------------------------------------------
# Main / Entry Point
# --------------------------------------------------------------------------------
require_no_arguments "$@" || exit 2
run_groups "$(dirname "$0")" $groupList
report_and_exit
