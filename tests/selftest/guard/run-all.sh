#!/usr/bin/env bash
# Self-test of the guard: runs the real guard helpers and rules against planted problems, so a rule that cannot fail is caught.
# - Each group runs real guard code, from the tree or from a scratch copy of it.
# - Each group makes its own work folder under TMPDIR and removes only that folder at exit.
# - Linux only, in the dev sandbox.
# - Usage, from anywhere: bash tests/selftest/guard/run-all.sh   (exit 0 = every case passes)
set -u
. "$(dirname "$0")/../lib-expect.sh"

# --------------------------------------------------------------------------------
# Group programs, in run order
# --------------------------------------------------------------------------------
groupList="helpers.sh host-rules.sh"

# --------------------------------------------------------------------------------
# Main / Entry Point
# --------------------------------------------------------------------------------
require_no_arguments "$@" || exit 2
run_groups "$(dirname "$0")" $groupList
report_and_exit
