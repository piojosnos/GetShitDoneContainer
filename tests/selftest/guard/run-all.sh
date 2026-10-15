#!/usr/bin/env bash
# ------------------------------------------------------------------------------
# Self-test of the guard: planted problems must fail the right rule
# ------------------------------------------------------------------------------
# Usage: bash tests/selftest/guard/run-all.sh (exit 0 = all pass)
# Linux only, in the dev sandbox.
# ------------------------------------------------------------------------------
set -u
. "$(dirname "$0")/../lib-expect.sh"

# ------------------------------------------------------------------------------
# Main / Entry Point
# ------------------------------------------------------------------------------
require_no_arguments "$@" || exit 2
run_groups "$(dirname "$0")"
report_and_exit
