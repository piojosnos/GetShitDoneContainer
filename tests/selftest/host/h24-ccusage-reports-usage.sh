#!/usr/bin/env bash
# Self-test of H-24 (tests/host/h24-ccusage-reports-usage.sh) against the fake docker: reports of the planted transcript pass; reports without it, a ccusage that cannot run and a missing test sandbox each fail.
# - Run by run-all.sh; runs alone too.
# - Makes one work folder under TMPDIR and removes only that folder at exit.
# - Usage, from anywhere: bash tests/selftest/host/h24-ccusage-reports-usage.sh   (exit 0 = every case passes)
set -u
. "$(dirname "$0")/lib.sh"

# --------------------------------------------------------------------------------
# Cases of H-24, each run alone against the fake docker
# --------------------------------------------------------------------------------
case_h24_alone() {
  local transcriptDir
  local transcriptCount

  echo "--- H-24 on its own"
  reset_state
  make_fixture_run
  transcriptDir="$FIXTURE/state/claude/projects/-home-sandbox-workspace-hosttest"
  run_standalone "$WORK/out.h24" h24-ccusage-reports-usage.sh
  expect "H-24: a report of the planted transcript passes" equals "$CHECK_RC" "0"
  expect "H-24: prints PASS: H-24" has_text "$WORK/out.h24" "PASS: H-24"
  expect "H-24: the transcript is in state/claude/projects with a run-unique session" \
    has_text "$transcriptDir/h24-usage.jsonl" '"sessionId":"h24-'
  expect "H-24: the daily report runs offline in the project folder" \
    has_text "$FAKE_LOG" "exec -w /home/sandbox/workspace/hosttest sbx-hosttest ccusage daily --offline --json --since 20200107 --until 20200107"
  expect "H-24: the monthly report runs offline in the project folder" \
    has_text "$FAKE_LOG" "exec -w /home/sandbox/workspace/hosttest sbx-hosttest ccusage monthly --offline --json --since 20200107 --until 20200107"
  expect "H-24: the session report runs offline in the project folder" \
    has_match "$FAKE_LOG" 'exec -w /home/sandbox/workspace/hosttest sbx-hosttest ccusage session --offline --json --id h24-'
  expect "H-24: the table report runs offline in the project folder" \
    has_text "$FAKE_LOG" "exec -w /home/sandbox/workspace/hosttest sbx-hosttest ccusage daily --offline --since 20200107 --until 20200107"

  run_standalone "$WORK/out.h24.again" h24-ccusage-reports-usage.sh
  transcriptCount=$(ls "$transcriptDir" | grep -c 'h24-usage.jsonl')
  expect "H-24: a second run passes with one transcript file" equals "$CHECK_RC $transcriptCount" "0 1"

  reset_state
  make_fixture_run
  run_standalone "$WORK/out.h24.empty" h24-ccusage-reports-usage.sh FAKE_CCUSAGE_EMPTY=1
  expect "H-24: a report without the planted usage fails" failed_with "$CHECK_RC" "$WORK/out.h24.empty" "ccusage daily lacks"

  reset_state
  make_fixture_run
  run_standalone "$WORK/out.h24.rc" h24-ccusage-reports-usage.sh FAKE_CCUSAGE_RC=1
  expect "H-24: a ccusage that cannot run fails" failed_with "$CHECK_RC" "$WORK/out.h24.rc" "exited 1"

  reset_state
  make_fixture_run
  run_standalone "$WORK/out.h24.scaled" h24-ccusage-reports-usage.sh FAKE_CCUSAGE_SCALE=10
  expect "H-24: token counts ten times too large fail" failed_with "$CHECK_RC" "$WORK/out.h24.scaled" "ccusage daily lacks"
  expect "H-24: the inflated session count fails too" has_text "$WORK/out.h24.scaled" "ccusage session lacks"
  expect "H-24: the inflated table fails too" has_text "$WORK/out.h24.scaled" "ccusage daily (table) lacks"

  reset_state
  make_fixture_run
  run_standalone "$WORK/out.h24.noise" h24-ccusage-reports-usage.sh FAKE_CCUSAGE_TABLE_NOISE=1
  expect "H-24: a table with 300 only inside a larger number and no Total row fails" failed_with "$CHECK_RC" "$WORK/out.h24.noise" "ccusage daily (table) lacks"

  reset_state
  FIXTURE=""
  run_standalone "$WORK/out.h24.none" h24-ccusage-reports-usage.sh
  expect "H-24: no test sandbox fails" equals "$CHECK_RC" "1"
  expect "H-24: no test sandbox says to run run-all.sh first" has_text "$WORK/out.h24.none" "run-all.sh first"
}

# --------------------------------------------------------------------------------
# Main / Entry Point
# --------------------------------------------------------------------------------
require_no_arguments "$@" || exit 2
start_group || exit 1
case_h24_alone
finish_cases
