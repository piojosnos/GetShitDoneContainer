#!/usr/bin/env bash
# Self-test of the Coexistence check (tests/host/coexistence.sh) against the fake docker: equal snapshots and clean old folders pass; a changed snapshot or a change under ClaudeCode/ fails; no baseline passes on git alone.
# - Run by run-all.sh; runs alone too.
# - Makes one work folder under TMPDIR and removes only that folder at exit.
# - Copies tests/host/*.sh into a scratch repo under the work folder, so tests/host/ stays exactly two levels deep.
# - Usage, from anywhere: bash tests/selftest/host/coexistence.sh   (exit 0 = every case passes)
set -u
. "$(dirname "$0")/lib.sh"

# --------------------------------------------------------------------------------
# Cases of Coexistence, each run alone against the fake docker
# --------------------------------------------------------------------------------
case_coexistence_alone() {
  echo "--- Coexistence on its own"
  reset_state
  make_fixture_run
  printf 'deadbeef0001 cc_oldbox running\n' >"$FIXTURE/logs/old-containers.before"
  run_standalone "$WORK/out.co" coexistence.sh
  expect "Coexistence: equal snapshots and clean old folders pass" equals "$CHECK_RC" "0"
  expect "Coexistence: prints PASS: Coexistence" has_text "$WORK/out.co" "PASS: Coexistence"
  run_standalone "$WORK/out.co.changed" coexistence.sh FAKE_PS="deadbeef0001 cc_oldbox exited"
  expect "Coexistence: a changed snapshot fails" equals "$CHECK_RC" "1"
  expect "Coexistence: a changed snapshot shows the before side" has_text "$WORK/out.co.changed" "cc_oldbox running"
  expect "Coexistence: a changed snapshot shows the after side" has_text "$WORK/out.co.changed" "cc_oldbox exited"
  expect "Coexistence: a changed snapshot says to re-run" has_text "$WORK/out.co.changed" "re-run"
  expect "Coexistence: the baseline is left as it was" \
    equals "$(cat "$FIXTURE/logs/old-containers.before")" "deadbeef0001 cc_oldbox running"
  reset_state
  FIXTURE=""
  run_standalone "$WORK/out.co.nobase" coexistence.sh
  expect "Coexistence: no baseline passes on git alone" equals "$CHECK_RC" "0"
  expect "Coexistence: no baseline says so" has_text "$WORK/out.co.nobase" "git only; no baseline"
  mkdir -p "$WORK/scratchrepo/tests/host" "$WORK/scratchrepo/ClaudeCode"
  cp tests/host/*.sh "$WORK/scratchrepo/tests/host/"
  git -C "$WORK/scratchrepo" init -q
  : >"$WORK/scratchrepo/ClaudeCode/stray.txt"
  CHECK_RC=0
  env SBXTEST_DIR="" bash "$WORK/scratchrepo/tests/host/coexistence.sh" >"$WORK/out.co.git" 2>&1 </dev/null || CHECK_RC=$?
  expect "Coexistence: a change under ClaudeCode/ fails" equals "$CHECK_RC" "1"
  expect "Coexistence: the changed path is shown" has_text "$WORK/out.co.git" "stray.txt"
}

# --------------------------------------------------------------------------------
# Main / Entry Point
# --------------------------------------------------------------------------------
require_no_arguments "$@" || exit 2
start_group || exit 1
case_coexistence_alone
finish_cases
