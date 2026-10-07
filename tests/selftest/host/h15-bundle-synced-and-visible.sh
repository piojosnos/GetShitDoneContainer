#!/usr/bin/env bash
# Self-test of H-15 (tests/host/h15-bundle-synced-and-visible.sh) against the fake docker: a synced bundle that Claude lists passes; a scoped rule loaded at start, missing skills, a tampered rule and a start with no sync fail.
# - Run by run-all.sh; runs alone too.
# - Makes one work folder under TMPDIR and removes only that folder at exit.
# - Usage, from anywhere: bash tests/selftest/host/h15-bundle-synced-and-visible.sh   (exit 0 = every case passes)
set -u
. "$(dirname "$0")/lib.sh"

# --------------------------------------------------------------------------------
# Cases of H-15, each run alone against the fake docker
# --------------------------------------------------------------------------------
case_h15_alone() {
  echo "--- H-15 on its own"
  reset_state
  make_fixture_run
  fake_start_sync "$FIXTURE"
  run_standalone "$WORK/out.h15" h15-bundle-synced-and-visible.sh
  expect "H-15: a synced bundle that Claude lists passes" equals "$CHECK_RC" "0"
  expect "H-15: prints PASS: H-15" has_text "$WORK/out.h15" "PASS: H-15"
  expect "H-15: the probe runs claude -p /context with a dummy key and no network" \
    has_match "$FAKE_LOG" 'ARGS: exec sbx-hosttest env ANTHROPIC_API_KEY=sk-ant-dummy ANTHROPIC_BASE_URL=http://127.0.0.1:1 claude -p /context$'
  run_standalone "$WORK/out.h15.scoped" h15-bundle-synced-and-visible.sh FAKE_CONTEXT_SCOPED=1
  expect "H-15: a path-scoped rule loaded at start fails" equals "$CHECK_RC" "1"
  expect "H-15: the loaded path-scoped rule is named" has_text "$WORK/out.h15.scoped" "shell.md"
  run_standalone "$WORK/out.h15.noskills" h15-bundle-synced-and-visible.sh FAKE_CONTEXT_NO_SKILLS=1
  expect "H-15: skills that Claude does not list fail" equals "$CHECK_RC" "1"
  expect "H-15: the missing skill is named" has_text "$WORK/out.h15.noskills" "merged"
  printf 'tampered\n' >>"$FIXTURE/state/claude/rules/communication.md"
  run_standalone "$WORK/out.h15.tamper" h15-bundle-synced-and-visible.sh
  expect "H-15: a synced rule that differs from the repo fails" equals "$CHECK_RC" "1"
  expect "H-15: the differing rule is named" has_text "$WORK/out.h15.tamper" "communication.md"
  reset_state
  make_fixture_run
  run_standalone "$WORK/out.h15.nosync" h15-bundle-synced-and-visible.sh
  expect "H-15: a start where the hook never ran fails" equals "$CHECK_RC" "1"
  expect "H-15: the missing rules folder is named" has_text "$WORK/out.h15.nosync" "state/claude/rules"
  reset_state
  FIXTURE=""
  run_standalone "$WORK/out.h15.none" h15-bundle-synced-and-visible.sh
  expect "H-15: no test sandbox fails" equals "$CHECK_RC" "1"
  expect "H-15: no test sandbox says to run run-all.sh first" has_text "$WORK/out.h15.none" "run-all.sh first"
}

# --------------------------------------------------------------------------------
# Main / Entry Point
# --------------------------------------------------------------------------------
require_no_arguments "$@" || exit 2
start_group || exit 1
case_h15_alone
finish_cases
