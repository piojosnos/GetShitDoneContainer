#!/usr/bin/env bash
# ------------------------------------------------------------------------------
# Self-test of the sbx-* host scripts, with no Docker
# ------------------------------------------------------------------------------
# Usage: bash tests/selftest/sbx/run-all.sh (exit 0 = all pass)
# What each suite is for and when to add a check: tests/README.md
# ------------------------------------------------------------------------------
set -u
. "$(dirname "$0")/../lib-expect.sh"

# ------------------------------------------------------------------------------
# Main / Entry Point
# ------------------------------------------------------------------------------
require_no_arguments "$@" || exit 2
run_groups "$(dirname "$0")"
report_and_exit
