#!/usr/bin/env bash
# Self-test of the host library units: claude_pin, pin_of, expected_arch, make_run_dir, the scrub in host_init and compose_up waiting for the start hooks.
# - Run by run-all.sh; runs alone too.
# - Makes one work folder under TMPDIR and removes only that folder at exit.
# - Usage, from anywhere: bash tests/selftest/host/units.sh   (exit 0 = every case passes)
set -u
. "$(dirname "$0")/lib.sh"

# --------------------------------------------------------------------------------
# Cases of the library units, run against the host library
# --------------------------------------------------------------------------------
case_lib_units() {
  echo "--- lib units"
  reset_state

  pinFromLib=$(lib_eval 'claude_pin')
  pinFromFile=$(sed -n 's/^CLAUDE_CODE_VERSION=//p' versions.env)
  expect "lib: claude_pin equals CLAUDE_CODE_VERSION in versions.env" equals "$pinFromLib" "$pinFromFile"
  expect "lib: claude_pin is not empty" string_matches '^[0-9]+\.[0-9]+\.[0-9]+$' "$pinFromLib"

  nodePinFromLib=$(lib_eval 'pin_of NODE_VERSION')
  nodePinFromFile=$(sed -n 's/^NODE_VERSION=//p' versions.env)
  expect "lib: pin_of NODE_VERSION equals its versions.env line" equals "$nodePinFromLib" "$nodePinFromFile"

  missingPin=$(lib_eval 'pin_of NO_SUCH_PIN')
  expect "lib: pin_of prints nothing for a name versions.env does not set" equals "$missingPin" ""

  archAarch=$( export FAKE_ARCH=aarch64; lib_eval 'expected_arch' )
  archIntel=$( export FAKE_ARCH=x86_64; lib_eval 'expected_arch' )
  archOther=$( export FAKE_ARCH=riscv64; lib_eval 'expected_arch' )
  expect "lib: expected_arch maps aarch64 to arm64" equals "$archAarch" "arm64"
  expect "lib: expected_arch maps x86_64 to amd64" equals "$archIntel" "amd64"
  expect "lib: expected_arch maps anything else to unknown" equals "$archOther" "unknown"

  madeRunDir=$(lib_eval 'make_run_dir; printf "%s" "$RUN"')
  madeBaseName=$(basename "$madeRunDir")
  expect "lib: make_run_dir name has the timestamp and random tail" \
    string_matches '^sbx-hosttest-[0-9]{8}-[0-9]{6}\.[A-Za-z0-9]{6}$' "$madeBaseName"
  expect "lib: make_run_dir creates hosttest, state and logs" \
    test -d "$madeRunDir/hosttest" -a -d "$madeRunDir/state" -a -d "$madeRunDir/logs"
  expect "lib: make_run_dir keeps the 0700 mode" \
    test -n "$(find "$madeRunDir" -maxdepth 0 -perm 0700)"

  scrubbed=$( export SBX_NAME=demo SBX_DIR=/elsewhere COMPOSE_PROJECT_NAME=evil
    lib_eval 'printf "SBX_NAME=%s SBX_DIR=%s COMPOSE_PROJECT_NAME=%s" "$SBX_NAME" "${SBX_DIR-unset}" "${COMPOSE_PROJECT_NAME-unset}"' )
  expect "lib: host_init ignores the caller's SBX_NAME, SBX_DIR and COMPOSE_PROJECT_NAME" \
    equals "$scrubbed" "SBX_NAME=hosttest SBX_DIR=unset COMPOSE_PROJECT_NAME=unset"

  composeScrubbed=$( export COMPOSE_ENV_FILES=/decoy.env COMPOSE_IGNORE_ORPHANS=1 COMPOSE_REMOVE_ORPHANS=1
    lib_eval 'printf "%s %s %s" "${COMPOSE_ENV_FILES-unset}" "${COMPOSE_IGNORE_ORPHANS-unset}" "${COMPOSE_REMOVE_ORPHANS-unset}"' )
  expect "lib: host_init clears COMPOSE_ENV_FILES, COMPOSE_IGNORE_ORPHANS and COMPOSE_REMOVE_ORPHANS" \
    equals "$composeScrubbed" "unset unset unset"
}

# --------------------------------------------------------------------------------
# Cases of compose_up, which waits until the start hooks have finished
# --------------------------------------------------------------------------------
case_compose_up_waits() {
  echo "--- compose_up waits for the start hooks"
  reset_state
  make_fixture_run
  upStatus=0
  ( export SBXTEST_DIR="$FIXTURE" FAKE_START_POLLS=2; lib_eval 'compose_up' ) >"$WORK/out.up.ok" 2>&1 || upStatus=$?
  expect "lib: compose_up returns once the start hooks finished" equals "$upStatus" "0"
  expect "lib: compose_up asked pgrep three times" \
    equals "$(grep -c 'ARGS: exec sbx-hosttest pgrep -x sleep' "$FAKE_LOG")" "3"

  reset_state
  make_fixture_run
  upStatus=0
  ( export SBXTEST_DIR="$FIXTURE" FAKE_START_POLLS=99 SBXTEST_START_SECONDS=2; lib_eval 'compose_up' ) >"$WORK/out.up.slow" 2>&1 || upStatus=$?
  expect "lib: compose_up fails when the start hooks never finish" failed_with "$upStatus" "$WORK/out.up.slow" "did not finish within 2 s"

  reset_state
  make_fixture_run
  upStatus=0
  ( export SBXTEST_DIR="$FIXTURE" FAKE_STOPS_AT_START=1; lib_eval 'compose_up' ) >"$WORK/out.up.stop" 2>&1 || upStatus=$?
  expect "lib: compose_up fails at once when the sandbox stops during its start" \
    failed_with "$upStatus" "$WORK/out.up.stop" "stopped during its start"
  expect "lib: compose_up asked pgrep once before it gave up on the stopped sandbox" \
    equals "$(grep -c 'ARGS: exec sbx-hosttest pgrep -x sleep' "$FAKE_LOG")" "1"
}

# --------------------------------------------------------------------------------
# Main / Entry Point
# --------------------------------------------------------------------------------
require_no_arguments "$@" || exit 2
start_group || exit 1
case_lib_units
case_compose_up_waits
finish_cases
