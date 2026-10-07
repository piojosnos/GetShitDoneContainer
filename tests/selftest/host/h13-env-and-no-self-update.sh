#!/usr/bin/env bash
# Self-test of H-13 (tests/host/h13-env-and-no-self-update.sh) against the fake docker: a missing variable, a self-update that runs, and a stray share folder each fail.
# - Run by run-all.sh; runs alone too.
# - Makes one work folder under TMPDIR and removes only that folder at exit.
# - Usage, from anywhere: bash tests/selftest/host/h13-env-and-no-self-update.sh   (exit 0 = every case passes)
set -u
. "$(dirname "$0")/lib.sh"

# --------------------------------------------------------------------------------
# Cases of H-13, each run alone against the fake docker
# --------------------------------------------------------------------------------
case_h13_alone() {
  echo "--- H-13 on its own"
  reset_state
  make_fixture_run
  run_standalone "$WORK/out.h13" h13-env-and-no-self-update.sh
  expect "H-13: five variables, updates disabled and no share folder pass" equals "$CHECK_RC" "0"
  expect "H-13: prints PASS: H-13" has_text "$WORK/out.h13" "PASS: H-13"
  run_standalone "$WORK/out.h13.env" h13-env-and-no-self-update.sh FAKE_ENV_MISSING=HISTFILE
  expect "H-13: a missing variable fails" equals "$CHECK_RC" "1"
  expect "H-13: the missing variable is named" has_text "$WORK/out.h13.env" "HISTFILE"
  run_standalone "$WORK/out.h13.update" h13-env-and-no-self-update.sh FAKE_UPDATE_ON=1
  expect "H-13: an update that runs fails" equals "$CHECK_RC" "1"
  run_standalone "$WORK/out.h13.share" h13-env-and-no-self-update.sh FAKE_SHARE_EXISTS=1
  expect "H-13: an existing share folder fails" equals "$CHECK_RC" "1"
  run_standalone "$WORK/out.h13.exec" h13-env-and-no-self-update.sh FAKE_EXEC_RC=125
  expect "H-13: an exec that could not run fails as could not check" \
    failed_with "$CHECK_RC" "$WORK/out.h13.exec" "could not check ~/.local/share/claude (docker exec exit 125)"
  expect "H-13: an exec that could not run is not called an existing folder" lacks_text "$WORK/out.h13.exec" "exists in the container home"
}

# --------------------------------------------------------------------------------
# failed_with STATUS FILE TEXT: true if STATUS is 1 and FILE contains TEXT.
# --------------------------------------------------------------------------------
failed_with() {
  [ "$1" = 1 ] && has_text "$2" "$3"
}

# --------------------------------------------------------------------------------
# Main / Entry Point
# --------------------------------------------------------------------------------
require_no_arguments "$@" || exit 2
start_group || exit 1
case_h13_alone
finish_cases
