#!/usr/bin/env bash
# Self-test of H-12 (tests/host/h12-plain-run-refused-pin-installed.sh) against the fake docker: a refused plain run and the pinned version pass; another installed version and a plain run that starts fail.
# - Run by run-all.sh; runs alone too.
# - Makes one work folder under TMPDIR and removes only that folder at exit.
# - Usage, from anywhere: bash tests/selftest/host/h12-plain-run-refused-pin-installed.sh   (exit 0 = every case passes)
set -u
. "$(dirname "$0")/lib.sh"

# --------------------------------------------------------------------------------
# Cases of H-12, each run alone against the fake docker
# --------------------------------------------------------------------------------
case_h12_alone() {
  echo "--- H-12 on its own"
  reset_state
  FIXTURE=""
  run_standalone "$WORK/out.h12" h12-plain-run-refused-pin-installed.sh
  expect "H-12: refused plain run and the pinned version pass" equals "$CHECK_RC" "0"
  expect "H-12: prints PASS: H-12" has_text "$WORK/out.h12" "PASS: H-12"
  run_standalone "$WORK/out.h12.pin" h12-plain-run-refused-pin-installed.sh FAKE_CLAUDE_VERSION=0.0.1
  expect "H-12: a different installed version fails" equals "$CHECK_RC" "1"
  expect "H-12: a different installed version prints FAIL: H-12" has_text "$WORK/out.h12.pin" "FAIL: H-12"
  run_standalone "$WORK/out.h12.plain" h12-plain-run-refused-pin-installed.sh FAKE_PLAIN_OK=1
  expect "H-12: a plain run that starts fails" equals "$CHECK_RC" "1"
}

# --------------------------------------------------------------------------------
# Main / Entry Point
# --------------------------------------------------------------------------------
require_no_arguments "$@" || exit 2
start_group || exit 1
case_h12_alone
finish_cases
