#!/usr/bin/env bash
# Self-test of H-20 (tests/host/h20-mistyped-name-refused.sh) against the fake docker: a sandbox folder without the project folder is refused and nothing is created; a start that is not refused and a refusal without the folder message fail, and the real sandbox is up at the end.
# - Run by run-all.sh; runs alone too.
# - Makes one work folder under TMPDIR and removes only that folder at exit.
# - Usage, from anywhere: bash tests/selftest/host/h20-mistyped-name-refused.sh   (exit 0 = every case passes)
set -u
. "$(dirname "$0")/lib.sh"

# --------------------------------------------------------------------------------
# Cases of H-20, each run alone against the fake docker on a fresh fixture
# --------------------------------------------------------------------------------
case_h20_alone() {
  local upCall

  echo "--- H-20 on its own"
  reset_state
  make_fixture_run
  run_standalone "$WORK/out.h20.ok" h20-mistyped-name-refused.sh
  expect "H-20: a sandbox folder without the project folder is refused" equals "$CHECK_RC" "0"
  expect "H-20: prints PASS: H-20" has_text "$WORK/out.h20.ok" "PASS: H-20"
  expect "H-20: nothing is created in that folder" test ! -e "$FIXTURE/h20/hosttest"
  expect "H-20: the real sandbox is up at the end" test -f "$WORK/state/container"
  expect "H-20: the real sandbox mounts the real run folder" equals "$(cat "$WORK/state/container.dir")" "$FIXTURE"
  expect "H-20: the real sandbox is not left exited" test ! -f "$WORK/state/container.exited"
  upCall=$(grep 'SBX_DIR='"$FIXTURE"'/h20 ' "$FAKE_LOG" | tail -n 1)
  expect "H-20: the start uses the folder without the project folder" \
    string_matches "SBX_NAME=hosttest SBX_DIR=$FIXTURE/h20 COMPOSE_PROJECT_NAME=unset ARGS: compose --env-file /dev/null -f .* up -d --wait$" "$upCall"

  reset_state
  make_fixture_run
  run_standalone "$WORK/out.h20.started" h20-mistyped-name-refused.sh FAKE_FOLDER_CHECK_OFF=1
  expect "H-20: a start that is not refused fails" equals "$CHECK_RC" "1"
  expect "H-20: a start that is not refused says the sandbox started" has_text "$WORK/out.h20.started" "the sandbox started"
  expect "H-20: the real sandbox is up at the end after a start" test -f "$WORK/state/container"

  reset_state
  make_fixture_run
  run_standalone "$WORK/out.h20.nolog" h20-mistyped-name-refused.sh FAKE_UP_RC=1
  expect "H-20: a refusal without the folder message fails" equals "$CHECK_RC" "1"
  expect "H-20: a refusal without the folder message says so" has_text "$WORK/out.h20.nolog" "does not say the project folder is missing"
}

# --------------------------------------------------------------------------------
# Main / Entry Point
# --------------------------------------------------------------------------------
require_no_arguments "$@" || exit 2
start_group || exit 1
case_h20_alone
finish_cases
