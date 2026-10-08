#!/usr/bin/env bash
# Self-test of H-21 (tests/host/h21-bad-name-refused.sh) against the fake docker: names that break the rule that are refused pass; an entrypoint without the name check, a start that fails for another reason and a missing run folder fail.
# - Run by run-all.sh; runs alone too.
# - Makes one work folder under TMPDIR and removes only that folder at exit.
# - Usage, from anywhere: bash tests/selftest/host/h21-bad-name-refused.sh   (exit 0 = every case passes)
set -u
. "$(dirname "$0")/lib.sh"

# --------------------------------------------------------------------------------
# Cases of H-21, each run alone against the fake docker
# --------------------------------------------------------------------------------
case_h21_alone() {
  echo "--- H-21 on its own"
  reset_state
  make_fixture_run
  run_standalone "$WORK/out.h21" h21-bad-name-refused.sh
  expect "H-21: names that break the rule are refused" equals "$CHECK_RC" "0"
  expect "H-21: prints PASS: H-21" has_text "$WORK/out.h21" "PASS: H-21"
  sed 's/^.*ARGS: //' "$FAKE_LOG" >"$WORK/args.h21"
  expect "H-21: both containers run with --rm, no network, no capabilities, no new privileges" \
    equals "$(grep -c '^run --rm --network none --cap-drop ALL --security-opt no-new-privileges:true ' "$WORK/args.h21")" "2"
  expect "H-21: both containers mount the h21 folder as the workspace" \
    equals "$(grep -F -c "type=bind,source=$FIXTURE/h21,target=/home/sandbox/workspace" "$WORK/args.h21")" "2"
  expect "H-21: one container gets HostTest" equals "$(grep -F -c -e '-e SBX_NAME=HostTest ' "$WORK/args.h21")" "1"
  expect "H-21: one container gets host_test" equals "$(grep -F -c -e '-e SBX_NAME=host_test ' "$WORK/args.h21")" "1"
  expect "H-21: no state folder is written" test ! -e "$FIXTURE/h21/state/shell"
}

# --------------------------------------------------------------------------------
# Cases of H-21 that must fail
# --------------------------------------------------------------------------------
case_h21_failures() {
  echo "--- H-21 must fail"
  reset_state
  make_fixture_run
  run_standalone "$WORK/out.h21.nocheck" h21-bad-name-refused.sh FAKE_ENTRY_NAME_CHECK_OFF=1
  expect "H-21: an entrypoint without the name check fails" failed_with "$CHECK_RC" "$WORK/out.h21.nocheck" "command ran"

  reset_state
  make_fixture_run
  run_standalone "$WORK/out.h21.offline" h21-bad-name-refused.sh FAKE_OFFLINE_FAIL=1
  expect "H-21: a start that fails for another reason fails" failed_with "$CHECK_RC" "$WORK/out.h21.offline" "not refused by the name rule"

  reset_state
  FIXTURE=""
  run_standalone "$WORK/out.h21.none" h21-bad-name-refused.sh
  expect "H-21: no run folder fails" failed_with "$CHECK_RC" "$WORK/out.h21.none" "no run folder"
}

# --------------------------------------------------------------------------------
# Main / Entry Point
# --------------------------------------------------------------------------------
require_no_arguments "$@" || exit 2
start_group || exit 1
case_h21_alone
case_h21_failures
finish_cases
