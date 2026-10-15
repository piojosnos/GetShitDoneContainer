#!/usr/bin/env bash
# ------------------------------------------------------------------------------
# Self-test of the start library: sourcing it runs nothing, running it checks
# ------------------------------------------------------------------------------
# Usage: bash tests/selftest/entrypoint/start-library.sh (exit 0 = all pass)
# Run by run-all.sh; its one work folder under TMPDIR is removed at exit.
# ------------------------------------------------------------------------------
set -u
. "$(dirname "$0")/lib.sh"

# ------------------------------------------------------------------------------
# Case: sourcing the start library runs no start step
# ------------------------------------------------------------------------------
case_sourcing_runs_nothing() {
  local sourceRc

  echo '--- sourcing the start library runs no start step'
  mkdir -p "$WORK/sourced"

  ( . "$START_LIB" ) >"$WORK/sourced/out" 2>&1 </dev/null
  sourceRc=$?

  expect "sourced: the library exits 0" equals "$sourceRc" 0
  expect "sourced: nothing is printed" test ! -s "$WORK/sourced/out"
}

# ------------------------------------------------------------------------------
# Case: executing the script runs the start checks and not the command
# ------------------------------------------------------------------------------
case_direct_run_checks() {
  local directRc

  echo '--- executing the script runs the start checks'
  mkdir -p "$WORK/direct"

  env -u SBX_NAME bash "$ENTRY" echo entrypoint-command-ran >"$WORK/direct/out" 2>&1 </dev/null
  directRc=$?

  expect "direct run: the script exits 1" equals "$directRc" 1
  expect "direct run: a start check printed [sbx] ERROR" has_text "$WORK/direct/out" "[sbx] ERROR:"
  expect "direct run: the command never ran" lacks_text "$WORK/direct/out" "entrypoint-command-ran"
}

# ------------------------------------------------------------------------------
# Main / Entry Point
# ------------------------------------------------------------------------------
require_no_arguments "$@" || exit 2
start_group || exit 1
case_sourcing_runs_nothing
case_direct_run_checks
finish_cases
