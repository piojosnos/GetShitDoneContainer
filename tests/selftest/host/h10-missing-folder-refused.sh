#!/usr/bin/env bash
# Self-test of H-10 (tests/host/h10-missing-folder-refused.sh) against the fake docker: a refused missing folder passes; a path that Docker created, a start on a missing folder and a start that fails for another reason fail, and the real sandbox is up at the end.
# - Run by run-all.sh; runs alone too.
# - Makes one work folder under TMPDIR and removes only that folder at exit.
# - Usage, from anywhere: bash tests/selftest/host/h10-missing-folder-refused.sh   (exit 0 = every case passes)
set -u
. "$(dirname "$0")/lib.sh"

# --------------------------------------------------------------------------------
# Cases of H-10, each run alone against the fake docker
# --------------------------------------------------------------------------------
case_h10_alone() {
  echo "--- H-10 on its own"
  reset_state
  make_fixture_run
  run_standalone "$WORK/out.h10.ok" h10-missing-folder-refused.sh
  expect "H-10: a refused missing folder with the path absent passes" equals "$CHECK_RC" "0"
  expect "H-10: prints PASS: H-10" has_text "$WORK/out.h10.ok" "PASS: H-10"
  expect "H-10: the bad path was not created" test ! -e "$FIXTURE/does-not-exist"
  expect "H-10: the real sandbox is up at the end" test -f "$WORK/state/container"
  lastComposeCall=$(grep 'ARGS: compose' "$FAKE_LOG" | tail -n 1)
  expect "H-10: the last compose call is an up with the real run folder" \
    string_matches "SBX_DIR=$FIXTURE COMPOSE_PROJECT_NAME=unset ARGS: compose .* up -d --wait$" "$lastComposeCall"
  reset_state
  make_fixture_run
  run_standalone "$WORK/out.h10.ign" h10-missing-folder-refused.sh FAKE_H10=ignored
  expect "H-10: a path that Docker created fails" equals "$CHECK_RC" "1"
  expect "H-10: the created path is reported as create_host_path ignored" has_text "$WORK/out.h10.ign" "create_host_path ignored"
  expect "H-10: the report carries the Compose version" has_text "$WORK/out.h10.ign" "Compose 2.39.1"
  expect "H-10: the created path is left for the printed cleanup" test -d "$FIXTURE/does-not-exist"
  expect "H-10: the real sandbox is up at the end after a created path" test -f "$WORK/state/container"
  expect "H-10: the real sandbox mounts the real run folder" equals "$(cat "$WORK/state/container.dir")" "$FIXTURE"
  reset_state
  make_fixture_run
  run_standalone "$WORK/out.h10.start" h10-missing-folder-refused.sh FAKE_H10=started
  expect "H-10: a start on a missing folder fails" equals "$CHECK_RC" "1"
  expect "H-10: a start on a missing folder says so" has_text "$WORK/out.h10.start" "started on a missing folder"
  expect "H-10: the real sandbox is up at the end after a start" test -f "$WORK/state/container"
  expect "H-10: the real sandbox mounts the real run folder after a start" equals "$(cat "$WORK/state/container.dir")" "$FIXTURE"
  reset_state
  make_fixture_run
  run_standalone "$WORK/out.h10.other" h10-missing-folder-refused.sh FAKE_H10=other
  expect "H-10: a start that fails for another reason fails" failed_with "$CHECK_RC" "$WORK/out.h10.other" "not because the folder is missing"
  expect "H-10: the real sandbox is up at the end after another failure" test -f "$WORK/state/container"
}

# --------------------------------------------------------------------------------
# Main / Entry Point
# --------------------------------------------------------------------------------
require_no_arguments "$@" || exit 2
start_group || exit 1
case_h10_alone
finish_cases
