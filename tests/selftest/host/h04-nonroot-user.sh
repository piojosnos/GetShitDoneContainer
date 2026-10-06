#!/usr/bin/env bash
# Self-test of H-04 (tests/host/h04-nonroot-user.sh) against the fake docker: the test sandbox running as the sandbox user passes; no sandbox and a container with another label fail.
# - Run by run-all.sh; runs alone too.
# - Makes one work folder under TMPDIR and removes only that folder at exit.
# - Usage, from anywhere: bash tests/selftest/host/h04-nonroot-user.sh   (exit 0 = every case passes)
set -u
. "$(dirname "$0")/lib.sh"

# --------------------------------------------------------------------------------
# Cases of H-04, each run alone against the fake docker
# --------------------------------------------------------------------------------
case_h04_alone() {
  echo "--- H-04 on its own"
  reset_state
  FIXTURE=""
  run_standalone "$WORK/out.h04.none" h04-nonroot-user.sh
  expect "H-04: no test sandbox fails" equals "$CHECK_RC" "1"
  expect "H-04: no test sandbox says to run run-all.sh" has_text "$WORK/out.h04.none" "run-all.sh"
  make_fixture_run
  run_standalone "$WORK/out.h04.ok" h04-nonroot-user.sh
  expect "H-04: the test sandbox passes" equals "$CHECK_RC" "0"
  run_standalone "$WORK/out.h04.foreign" h04-nonroot-user.sh FAKE_LABEL=other
  expect "H-04: a container with another label is refused" equals "$CHECK_RC" "1"
}

# --------------------------------------------------------------------------------
# Main / Entry Point
# --------------------------------------------------------------------------------
require_no_arguments "$@" || exit 2
start_group || exit 1
case_h04_alone
finish_cases
