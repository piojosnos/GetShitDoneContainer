#!/usr/bin/env bash
# Self-test of H-18 (tests/host/h18-scope-and-deny.sh) against the fake docker: a scoped rule that loads late and a deny that holds pass; an eager load, a broken deny, tools that never ran and no test sandbox fail.
# - Run by run-all.sh; runs alone too.
# - Makes one work folder under TMPDIR and removes only that folder at exit.
# - Usage, from anywhere: bash tests/selftest/host/h18-scope-and-deny.sh   (exit 0 = every case passes)
set -u
. "$(dirname "$0")/lib.sh"

# --------------------------------------------------------------------------------
# every_scenario_in_project_folder: true if the log has at least one scenario exec and each one passes -w for the project folder.
# --------------------------------------------------------------------------------
every_scenario_in_project_folder() {
  local scenarioCount projectCount

  scenarioCount=$(grep -c 'H18_SCRIPT=' "$FAKE_LOG")
  projectCount=$(grep -c 'ARGS: exec -w /home/sandbox/workspace/hosttest sbx-hosttest .*H18_SCRIPT=' "$FAKE_LOG")

  [ "$scenarioCount" -gt 0 ] && [ "$scenarioCount" = "$projectCount" ]
}

# --------------------------------------------------------------------------------
# Cases of H-18, each run alone against the fake docker
# --------------------------------------------------------------------------------
case_h18_alone() {
  echo "--- H-18 on its own"
  reset_state
  make_fixture_run
  fake_start_sync "$FIXTURE"
  run_standalone "$WORK/out.h18" h18-scope-and-deny.sh
  expect "H-18: a scoped rule that loads late and a deny that holds pass" equals "$CHECK_RC" "0"
  expect "H-18: prints PASS: H-18" has_text "$WORK/out.h18" "PASS: H-18"
  expect "H-18: the fake API server is copied into the run folder's logs" test -f "$FIXTURE/logs/fake-claude-api.js"
  expect "H-18: the probe file is under the project folder" test -f "$FIXTURE/hosttest/h18/deep/probe.sh"
  expect "H-18: the project file was edited" equals "$(cat "$FIXTURE/hosttest/h18/control.txt")" "h18 control after"
  expect "H-18: both scenario scripts name container paths" has_text "$FIXTURE/logs/h18-deny.json" "/home/sandbox/workspace/state/claude/rules/"
  expect "H-18: the exec runs with the fake API script and log in the environment" \
    has_match "$FAKE_LOG" 'ARGS: exec( -w [^ ]+)? sbx-hosttest env H18_SCRIPT=/home/sandbox/workspace/logs/h18-scope.json H18_LOG=/home/sandbox/workspace/logs/h18-scope.log '
  expect "H-18: Claude runs in the project folder" every_scenario_in_project_folder
  run_standalone "$WORK/out.h18.eager" h18-scope-and-deny.sh FAKE_SCOPE_EAGER=1
  expect "H-18: a path-scoped rule loaded at the first request fails" equals "$CHECK_RC" "1"
  expect "H-18: the eager load is named" has_text "$WORK/out.h18.eager" "loaded before any matching file was touched"
  fake_start_sync "$FIXTURE"
  run_standalone "$WORK/out.h18.broken" h18-scope-and-deny.sh FAKE_DENY_BROKEN=1
  expect "H-18: a broken deny fails" equals "$CHECK_RC" "1"
  expect "H-18: the changed rule is named" has_text "$WORK/out.h18.broken" "state/claude/rules/coding-general.md was changed"
  expect "H-18: the planted file is named" has_text "$WORK/out.h18.broken" "h18-planted.md"
  fake_start_sync "$FIXTURE"
  run_standalone "$WORK/out.h18.off" h18-scope-and-deny.sh FAKE_H18_TOOLS_OFF=1
  expect "H-18: tools that never ran fail" equals "$CHECK_RC" "1"
  expect "H-18: tools that never ran say the deny result proves nothing" has_text "$WORK/out.h18.off" "the edit tool never ran, so the deny result proves nothing"
  reset_state
  FIXTURE=""
  run_standalone "$WORK/out.h18.none" h18-scope-and-deny.sh
  expect "H-18: no test sandbox fails" equals "$CHECK_RC" "1"
  expect "H-18: no test sandbox says to run run-all.sh first" has_text "$WORK/out.h18.none" "run-all.sh first"
}

# --------------------------------------------------------------------------------
# Main / Entry Point
# --------------------------------------------------------------------------------
require_no_arguments "$@" || exit 2
start_group || exit 1
case_h18_alone
finish_cases
