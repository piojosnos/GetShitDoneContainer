#!/usr/bin/env bash
# Self-test of how tests/host/run-all.sh handles failures against the fake docker: a failing check, a start that never synced, a failed build, a foreign leftover container, a sandbox that does not start, a chain that stops, failures that do not stop the run, and a fatal Compose check, and a failed docker ps at the start.
# - Run by run-all.sh; runs alone too.
# - Makes one work folder under TMPDIR and removes only that folder at exit.
# - Usage, from anywhere: bash tests/selftest/host/runner-failures.sh   (exit 0 = every case passes)
set -u
. "$(dirname "$0")/lib.sh"

# --------------------------------------------------------------------------------
# A check fails
# --------------------------------------------------------------------------------
case_failing_check() {
  echo "--- failing check"
  reset_state
  run_runner "$WORK/out.badid" FAKE_ID="uid=0(root) gid=0(root)"
  expect "runner: a wrong id exits 1" equals "$RUNNER_RC" "1"
  expect "runner: a wrong id prints FAIL: H-04" has_text "$WORK/out.badid" "FAIL: H-04"
  expect "runner: a wrong id still prints the summary" has_text "$WORK/out.badid" "Summary: 18 passed, 1 failed, 0 not run"
  expect "runner: a wrong id still prints the Next block" has_text "$WORK/out.badid" "If something looks wrong, see tests/host/manual/"
}

# --------------------------------------------------------------------------------
# The start never ran the bundle sync
# --------------------------------------------------------------------------------
case_no_bundle_sync() {
  echo "--- sandbox started without the bundle sync"
  reset_state
  run_runner "$WORK/out.nosync" FAKE_NO_SYNC=1
  expect "runner: a start that never synced exits 1" equals "$RUNNER_RC" "1"
  expect "runner: a start that never synced prints FAIL: H-15" has_text "$WORK/out.nosync" "FAIL: H-15"
}

# --------------------------------------------------------------------------------
# A build fails
# --------------------------------------------------------------------------------
case_failed_build() {
  echo "--- failed build"
  reset_state
  run_runner "$WORK/out.build" FAKE_BUILD_FAIL=sbx-claude:local
  expect "runner: a failed build exits 1" equals "$RUNNER_RC" "1"
  expect "runner: a failed build runs no check" lacks_match "$WORK/out.build" '^(PASS|FAIL): H-04'
  expect "runner: a failed build prints the log path" has_text "$WORK/out.build" "logs/build-claude.log"
  expect "runner: a failed build still prints the Next block" has_text "$WORK/out.build" "If something looks wrong, see tests/host/manual/"
}

# --------------------------------------------------------------------------------
# A container named like the test sandbox is not the test sandbox
# --------------------------------------------------------------------------------
case_leftover_container() {
  echo "--- leftover container that is not the test sandbox"
  reset_state
  pre_create_container "/old/sbx-hosttest-leftover"
  run_runner "$WORK/out.leftover" FAKE_LABEL=other
  expect "runner: a foreign sbx-hosttest container exits 1" equals "$RUNNER_RC" "1"
  expect "runner: a foreign sbx-hosttest container is reported" has_text "$WORK/out.leftover" "FAIL: SETUP"
  expect "runner: a foreign sbx-hosttest container is never taken down" lacks_match "$FAKE_LOG" 'ARGS: compose .*down'
}

# --------------------------------------------------------------------------------
# The sandbox does not start
# --------------------------------------------------------------------------------
case_sandbox_does_not_start() {
  echo "--- sandbox does not start"
  reset_state
  run_runner "$WORK/out.up" FAKE_UP_RC=1
  expect "runner: a failed up exits 1" equals "$RUNNER_RC" "1"
  expect "runner: a failed up prints FAIL: SETUP" has_text "$WORK/out.up" "FAIL: SETUP"
  expect "runner: a failed up marks the sandbox checks not run" has_text "$WORK/out.up" "NOT RUN: h04-nonroot-user.sh"
}

# --------------------------------------------------------------------------------
# The full chain, including a folder that should not exist and a container that stays up
# --------------------------------------------------------------------------------
case_full_chain() {
  echo "--- full chain in the runner"
  reset_state
  run_runner "$WORK/out.chain.ign" FAKE_H10=ignored
  expect "runner: a created missing folder exits 1" equals "$RUNNER_RC" "1"
  expect "runner: a created missing folder prints FAIL: H-10" has_text "$WORK/out.chain.ign" "FAIL: H-10"
  expect "runner: a created missing folder still runs Coexistence" has_text "$WORK/out.chain.ign" "PASS: Coexistence"
  expect "runner: a created missing folder still prints the Next block" has_text "$WORK/out.chain.ign" "If something looks wrong, see tests/host/manual/"
  reset_state
  run_runner "$WORK/out.chain.keep" FAKE_DOWN_KEEPS=1
  expect "runner: a kept container exits 1" equals "$RUNNER_RC" "1"
  expect "runner: a kept container prints FAIL: H-11" has_text "$WORK/out.chain.keep" "FAIL: H-11"
  expect "runner: the chain stops, so H-09 is not run" has_text "$WORK/out.chain.keep" "NOT RUN: h09-rebuild-keeps-files-no-volumes.sh"
  expect "runner: the chain stops, so H-10 is not run" has_text "$WORK/out.chain.keep" "NOT RUN: h10-missing-folder-refused.sh"
  expect "runner: H-09 prints no result after the chain stopped" lacks_match "$WORK/out.chain.keep" '^(PASS|FAIL): H-(09|10)'
  expect "runner: Coexistence still runs after the chain stopped" has_text "$WORK/out.chain.keep" "PASS: Coexistence"
  reset_state
  run_runner "$WORK/out.nocache" SBXTEST_NO_CACHE=1
  sed 's/^.*ARGS: //' "$FAKE_LOG" >"$WORK/args.nocache"
  expect "runner: SBXTEST_NO_CACHE=1 run exits 0" equals "$RUNNER_RC" "0"
  expect "runner: the first builds use the cache" equals "$(grep -c '^build -f ' "$WORK/args.nocache")" "2"
  expect "runner: only the rebuild uses --no-cache" equals "$(grep -c '^build --no-cache ' "$WORK/args.nocache")" "2"
}

# --------------------------------------------------------------------------------
# An H-18 failure does not stop the run
# --------------------------------------------------------------------------------
case_h18_failure_continues() {
  echo "--- H-18 failure does not stop the runner"
  reset_state
  run_runner "$WORK/out.h18keep" FAKE_DENY_BROKEN=1
  expect "runner: an H-18 failure exits 1" equals "$RUNNER_RC" "1"
  expect "runner: an H-18 failure prints FAIL: H-18" has_text "$WORK/out.h18keep" "FAIL: H-18"
  expect "runner: an H-18 failure marks no check not run" lacks_text "$WORK/out.h18keep" "NOT RUN"
  expect "runner: an H-18 failure still runs the chain" has_text "$WORK/out.h18keep" "PASS: H-16"
  expect "runner: an H-18 failure is in the summary" has_text "$WORK/out.h18keep" "Summary: 18 passed, 1 failed, 0 not run"
  expect "runner: an H-18 failure is listed" has_text "$WORK/out.h18keep" "Failed: h18-scope-and-deny.sh"
}

# --------------------------------------------------------------------------------
# A fatal H-00 stops everything
# --------------------------------------------------------------------------------
case_fatal_h00() {
  echo "--- fatal H-00 in the runner"
  reset_state
  run_runner "$WORK/out.h00fatal" FAKE_COMPOSE_VERSION=1.29.2
  expect "runner: Compose 1.x exits 1" equals "$RUNNER_RC" "1"
  expect "runner: Compose 1.x prints FAIL: H-00" has_text "$WORK/out.h00fatal" "FAIL: H-00"
  expect "runner: Compose 1.x builds nothing" lacks_text "$FAKE_LOG" "ARGS: build"
  expect "runner: Compose 1.x still prints the Next block" has_text "$WORK/out.h00fatal" "If something looks wrong, see tests/host/manual/"
}

# --------------------------------------------------------------------------------
# docker ps fails at the start, so the old containers cannot be recorded
# --------------------------------------------------------------------------------
case_failed_ps_at_start() {
  echo "--- docker ps fails at the start of the run"
  reset_state
  run_runner "$WORK/out.psfail" FAKE_PS_FAIL=1
  expect "runner: a failed docker ps at the start stops the run" \
    failed_with "$RUNNER_RC" "$WORK/out.psfail" "FAIL: SETUP docker ps failed; the old containers cannot be recorded"
  expect "runner: no check runs after a failed docker ps" has_text "$WORK/out.psfail" "NOT RUN: h00-compose-v2.sh"
}

# --------------------------------------------------------------------------------
# An H-02 failure does not stop the run
# --------------------------------------------------------------------------------
case_h02_failure_continues() {
  echo "--- H-02 failure does not stop the runner"
  reset_state
  run_runner "$WORK/out.h02keep" FAKE_CLAUDE_LAYERS="sha256:x1 sha256:c1"
  expect "runner: an H-02 failure exits 1" equals "$RUNNER_RC" "1"
  expect "runner: an H-02 failure prints FAIL: H-02" has_text "$WORK/out.h02keep" "FAIL: H-02"
  expect "runner: an H-02 failure still runs H-04" has_text "$WORK/out.h02keep" "PASS: H-04"
  expect "runner: an H-02 failure still runs H-12" has_text "$WORK/out.h02keep" "PASS: H-12"
  expect "runner: an H-02 failure is in the summary" has_text "$WORK/out.h02keep" "Failed: h02-claude-on-base.sh"
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
case_failing_check
case_no_bundle_sync
case_failed_build
case_leftover_container
case_sandbox_does_not_start
case_full_chain
case_h18_failure_continues
case_fatal_h00
case_h02_failure_continues
case_failed_ps_at_start
finish_cases
