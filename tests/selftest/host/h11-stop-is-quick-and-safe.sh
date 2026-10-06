#!/usr/bin/env bash
# Self-test of H-11 (tests/host/h11-stop-is-quick-and-safe.sh) against the fake docker: a quick stop that keeps the folders passes; a container still present after down fails.
# - Run by run-all.sh; runs alone too.
# - Makes one work folder under TMPDIR and removes only that folder at exit.
# - Usage, from anywhere: bash tests/selftest/host/h11-stop-is-quick-and-safe.sh   (exit 0 = every case passes)
set -u
. "$(dirname "$0")/lib.sh"

# --------------------------------------------------------------------------------
# Cases of H-11, each run alone against the fake docker
# --------------------------------------------------------------------------------
case_h11_alone() {
  echo "--- H-11 on its own"
  reset_state
  make_fixture_run
  run_standalone "$WORK/out.h11" h11-stop-is-quick-and-safe.sh
  expect "H-11: a quick stop that keeps the folders passes" equals "$CHECK_RC" "0"
  expect "H-11: prints PASS: H-11" has_text "$WORK/out.h11" "PASS: H-11"
  expect "H-11: the sentinel in the project folder is intact" test -f "$FIXTURE/hosttest/h11-sentinel.txt"
  expect "H-11: the sentinel in the state folder is intact" test -f "$FIXTURE/state/h11-sentinel.txt"
  expect "H-11: the sandbox is up again" test -f "$WORK/state/container"
  reset_state
  make_fixture_run
  run_standalone "$WORK/out.h11.kept" h11-stop-is-quick-and-safe.sh FAKE_DOWN_KEEPS=1
  expect "H-11: a container still present after down fails" equals "$CHECK_RC" "1"
  expect "H-11: the kept container is the reason" has_text "$WORK/out.h11.kept" "still exists"
}

# --------------------------------------------------------------------------------
# Main / Entry Point
# --------------------------------------------------------------------------------
require_no_arguments "$@" || exit 2
start_group || exit 1
case_h11_alone
finish_cases
