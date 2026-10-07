#!/usr/bin/env bash
# Self-test of the start library itself: sourcing it runs nothing, and running base/sbx-entrypoint runs the start checks.
# - Proves that sourcing base/sbx-start-lib.sh prints nothing and exits 0.
# - Proves that executing base/sbx-entrypoint runs the start checks and never the command it was given.
# - Run by run-all.sh; runs alone too.
# - Makes one work folder under TMPDIR and removes only that folder at exit.
# - Usage, from anywhere: bash tests/selftest/entrypoint/start-library.sh   (exit 0 = every case passes)
set -u
. "$(dirname "$0")/lib.sh"

# --------------------------------------------------------------------------------
# Case: sourcing the start library runs no start step
# --------------------------------------------------------------------------------
case_sourcing_runs_nothing() {
  local sourceRc

  echo '--- sourcing the start library runs no start step'
  mkdir -p "$WORK/sourced"

  ( . "$START_LIB" ) >"$WORK/sourced/out" 2>&1 </dev/null
  sourceRc=$?

  expect "sourced: the library exits 0" equals "$sourceRc" 0
  expect "sourced: nothing is printed" test ! -s "$WORK/sourced/out"
}

# --------------------------------------------------------------------------------
# Case: executing the script runs the start checks and not the command
# --------------------------------------------------------------------------------
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

# --------------------------------------------------------------------------------
# Main / Entry Point
# --------------------------------------------------------------------------------
require_no_arguments "$@" || exit 2
start_group || exit 1
case_sourcing_runs_nothing
case_direct_run_checks
finish_cases
