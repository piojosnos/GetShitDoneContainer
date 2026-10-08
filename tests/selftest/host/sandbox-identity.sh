#!/usr/bin/env bash
# Self-test of the test sandbox identity rules in tests/host/lib-sandbox.sh: a check acts only on this run's sandbox, cleanup takes down any test sandbox.
# - Run by run-all.sh; runs alone too.
# - Strict rule (require_test_sandbox): the sandbox must mount the run folder of this run.
# - Loose rule (compose_down): the sandbox mounts a sbx-hosttest-* folder, or a folder directly inside one.
# - Makes one work folder under TMPDIR and removes only that folder at exit.
# - Usage, from anywhere: bash tests/selftest/host/sandbox-identity.sh   (exit 0 = every case passes)
set -u
. "$(dirname "$0")/lib.sh"

# --------------------------------------------------------------------------------
# down_with_mount MOUNT OUTFILE: runs compose_down for a fresh run folder while the fake sandbox mounts MOUNT; sets DOWN_RC.
# --------------------------------------------------------------------------------
down_with_mount() {
  reset_state
  make_fixture_run
  pre_create_container "$1"
  DOWN_RC=0
  ( export SBXTEST_DIR="$FIXTURE"; lib_eval compose_down ) >"$2" 2>&1 </dev/null || DOWN_RC=$?
}

# --------------------------------------------------------------------------------
# down_before_first_build LOG: true when the docker log has a compose down call before its first build call.
# --------------------------------------------------------------------------------
down_before_first_build() {
  local downLine buildLine

  downLine=$(grep -n 'ARGS: compose .* down' "$1" | head -n 1 | cut -d: -f1)
  buildLine=$(grep -n 'ARGS: build ' "$1" | head -n 1 | cut -d: -f1)

  if [ -z "$downLine" ] || [ -z "$buildLine" ]; then
    return 1
  fi

  [ "$downLine" -lt "$buildLine" ]
}

# --------------------------------------------------------------------------------
# Cases of the strict rule: a check refuses a sandbox that mounts another run folder
# --------------------------------------------------------------------------------
case_check_refuses_other_run() {
  local runA runB

  echo "--- a check and another run's sandbox"
  reset_state
  make_fixture_run
  runA=$FIXTURE
  make_fixture_run
  runB=$FIXTURE
  FIXTURE=$runA
  run_standalone "$WORK/out.other" h04-nonroot-user.sh

  expect "identity: a check refuses a sandbox that mounts another run folder" equals "$CHECK_RC" "1"
  expect "identity: the other run folder is named" has_text "$WORK/out.other" "$(basename "$runB")"
}

# --------------------------------------------------------------------------------
# Cases of the loose rule: cleanup takes down any test sandbox and nothing else
# --------------------------------------------------------------------------------
case_cleanup_takes_down_test_sandboxes() {
  echo "--- cleanup and the loose rule"

  reset_state
  pre_create_container "$WORK/tmp/sbx-hosttest-20000101-000000.abcdef"
  run_runner "$WORK/out.earlier"
  expect "identity: an earlier run's test sandbox is still taken down" equals "$RUNNER_RC" "0"
  expect "identity: the earlier run's sandbox is taken down before the first build" down_before_first_build "$FAKE_LOG"

  down_with_mount /x/old-sbx-hosttest-copy "$WORK/out.lookalike"
  expect "identity: a mount that only contains the run prefix is refused" equals "$DOWN_RC" "1"
  expect "identity: the lookalike refusal is reported" has_text "$WORK/out.lookalike" "Refusing compose down"

  down_with_mount /x/sbx-hosttest-y/a/real "$WORK/out.deep"
  expect "identity: a mount two levels below a run folder is refused" equals "$DOWN_RC" "1"
  expect "identity: the deep refusal is reported" has_text "$WORK/out.deep" "Refusing compose down"

  reset_state
  make_fixture_run
  pre_create_container "$FIXTURE/h20"
  DOWN_RC=0
  ( export SBXTEST_DIR="$FIXTURE"; lib_eval compose_down ) >"$WORK/out.inside" 2>&1 </dev/null || DOWN_RC=$?
  expect "identity: a sandbox on a folder inside the run folder can be taken down" equals "$DOWN_RC" "0"
}

# --------------------------------------------------------------------------------
# Main / Entry Point
# --------------------------------------------------------------------------------
require_no_arguments "$@" || exit 2
start_group || exit 1
case_check_refuses_other_run
case_cleanup_takes_down_test_sandboxes
finish_cases
