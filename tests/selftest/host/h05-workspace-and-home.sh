#!/usr/bin/env bash
# Self-test of H-05 (tests/host/h05-workspace-and-home.sh) against the fake docker: a file on the host, the home listing and the sandbox owners pass; a file that never arrives and a root owner fail.
# - Run by run-all.sh; runs alone too.
# - Makes one work folder under TMPDIR and removes only that folder at exit.
# - Usage, from anywhere: bash tests/selftest/host/h05-workspace-and-home.sh   (exit 0 = every case passes)
set -u
. "$(dirname "$0")/lib.sh"

# --------------------------------------------------------------------------------
# run_unique_file_count DIR: prints how many files named x-NUMBER-NUMBER.txt are in DIR.
# --------------------------------------------------------------------------------
run_unique_file_count() {
  ls "$1" 2>/dev/null | grep -c '^x-[0-9][0-9]*-[0-9][0-9]*\.txt$'
}

# --------------------------------------------------------------------------------
# Cases of H-05, each run alone against the fake docker
# --------------------------------------------------------------------------------
case_h05_alone() {
  echo "--- H-05 on its own"
  reset_state
  make_fixture_run
  run_standalone "$WORK/out.h05" h05-workspace-and-home.sh
  expect "H-05: the file on the host, .bashrc and .local listed, sandbox owners pass" equals "$CHECK_RC" "0"
  expect "H-05: prints PASS: H-05" has_text "$WORK/out.h05" "PASS: H-05"
  expect "H-05: the file made in the container is in the run folder" equals "$(run_unique_file_count "$FIXTURE/hosttest")" "1"
  reset_state
  make_fixture_run
  run_standalone "$WORK/out.h05.notouch" h05-workspace-and-home.sh FAKE_NO_TOUCH=1
  expect "H-05: a file that never reaches the host fails" equals "$CHECK_RC" "1"
  expect "H-05: the missing file is named" has_text "$WORK/out.h05.notouch" "did not appear"
  reset_state
  make_fixture_run
  : >"$FIXTURE/hosttest/x.txt"
  run_standalone "$WORK/out.h05.stale" h05-workspace-and-home.sh FAKE_NO_TOUCH=1
  expect "H-05: a file left by an earlier run does not pass" equals "$CHECK_RC" "1"
  reset_state
  make_fixture_run
  run_standalone "$WORK/out.h05.root" h05-workspace-and-home.sh FAKE_STAT_OWNER=root
  expect "H-05: a root owner fails" equals "$CHECK_RC" "1"
  expect "H-05: the root owner is shown" has_text "$WORK/out.h05.root" "root /home/sandbox/.local"
}

# --------------------------------------------------------------------------------
# Main / Entry Point
# --------------------------------------------------------------------------------
require_no_arguments "$@" || exit 2
start_group || exit 1
case_h05_alone
finish_cases
