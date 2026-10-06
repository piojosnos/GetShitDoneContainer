#!/usr/bin/env bash
# Self-test of H-08 (tests/host/h08-history-survives-recreate.sh) against the fake docker: a history that is never written or is lost on recreate fails.
# - Run by run-all.sh; runs alone too.
# - Makes one work folder under TMPDIR and removes only that folder at exit.
# - Usage, from anywhere: bash tests/selftest/host/h08-history-survives-recreate.sh   (exit 0 = every case passes)
set -u
. "$(dirname "$0")/lib.sh"

# --------------------------------------------------------------------------------
# Cases of H-08, each run alone against the fake docker
# --------------------------------------------------------------------------------
case_h08_alone() {
  echo "--- H-08 on its own"
  reset_state
  make_fixture_run
  run_standalone "$WORK/out.h08" h08-history-survives-recreate.sh
  expect "H-08: a marker written while a shell is open survives the recreate" equals "$CHECK_RC" "0"
  expect "H-08: prints PASS: H-08" has_text "$WORK/out.h08" "PASS: H-08"
  expect "H-08: the history file is in the run folder" has_text "$FIXTURE/state/shell/bash_history" "echo marker-"
  expect "H-08: the sandbox is down and up once" equals "$(grep -c 'ARGS: compose .* \(up\|down\)' "$FAKE_LOG")" "2"
  reset_state
  make_fixture_run
  run_standalone "$WORK/out.h08.nohist" h08-history-survives-recreate.sh FAKE_NO_HISTORY=1
  expect "H-08: a marker that never reaches the history file fails" equals "$CHECK_RC" "1"
  expect "H-08: the failing half is the first one" has_text "$WORK/out.h08.nohist" "before the recreate"
  reset_state
  make_fixture_run
  run_standalone "$WORK/out.h08.lost" h08-history-survives-recreate.sh FAKE_DOWN_LOSES_HISTORY=1
  expect "H-08: history lost by the recreate fails" equals "$CHECK_RC" "1"
  expect "H-08: the failing half is the second one" has_text "$WORK/out.h08.lost" "after the recreate"
}

# --------------------------------------------------------------------------------
# Main / Entry Point
# --------------------------------------------------------------------------------
require_no_arguments "$@" || exit 2
start_group || exit 1
case_h08_alone
finish_cases
