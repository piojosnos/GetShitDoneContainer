#!/usr/bin/env bash
# Self-test of H-03 (tests/host/h03-variable-interpolation.sh) against the fake docker: the right project name with SBX_DIR required passes; a wrong name and a config that works without SBX_DIR fail.
# - Run by run-all.sh; runs alone too.
# - Makes one work folder under TMPDIR and removes only that folder at exit.
# - Usage, from anywhere: bash tests/selftest/host/h03-variable-interpolation.sh   (exit 0 = every case passes)
set -u
. "$(dirname "$0")/lib.sh"

# --------------------------------------------------------------------------------
# Cases of H-03, each run alone against the fake docker
# --------------------------------------------------------------------------------
case_h03_alone() {
  echo "--- H-03 on its own"
  reset_state
  make_fixture_run
  run_standalone "$WORK/out.h03" h03-variable-interpolation.sh
  expect "H-03: both halves right pass" equals "$CHECK_RC" "0"
  expect "H-03: prints PASS: H-03" has_text "$WORK/out.h03" "PASS: H-03"
  FIXTURE=""
  reset_state
  run_standalone "$WORK/out.h03.norun" h03-variable-interpolation.sh
  expect "H-03: passes without a running sandbox" equals "$CHECK_RC" "0"
  run_standalone "$WORK/out.h03.name" h03-variable-interpolation.sh FAKE_CONFIG_NAME=sbx-other
  expect "H-03: a wrong project name fails" equals "$CHECK_RC" "1"
  expect "H-03: a wrong project name names that half" has_text "$WORK/out.h03.name" "name: sbx-hosttest"
  run_standalone "$WORK/out.h03.lax" h03-variable-interpolation.sh FAKE_CONFIG_LAX=1
  expect "H-03: a config that works without SBX_DIR fails" equals "$CHECK_RC" "1"
  expect "H-03: a config that works without SBX_DIR names that half" has_text "$WORK/out.h03.lax" "SBX_DIR is required"
  run_standalone "$WORK/out.h03.dotenv" h03-variable-interpolation.sh FAKE_DOTENV_SBX_DIR=/sbx-hosttest-dotenv
  expect "H-03: a repo .env that sets SBX_DIR does not hide the missing-SBX_DIR refusal" equals "$CHECK_RC" "0"
}

# --------------------------------------------------------------------------------
# Main / Entry Point
# --------------------------------------------------------------------------------
require_no_arguments "$@" || exit 2
start_group || exit 1
case_h03_alone
finish_cases
