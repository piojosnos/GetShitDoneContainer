#!/usr/bin/env bash
# Self-test of the host library units: claude_pin, expected_arch, make_run_dir and the scrub in host_init.
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
  pinFromFile=$(grep '^ARG CLAUDE_CODE_VERSION=' claude/Dockerfile | cut -d= -f2)
  expect "lib: claude_pin equals the ARG in claude/Dockerfile" equals "$pinFromLib" "$pinFromFile"
  expect "lib: claude_pin is not empty" string_matches '^[0-9]+\.[0-9]+\.[0-9]+$' "$pinFromLib"

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
}

# --------------------------------------------------------------------------------
# Main / Entry Point
# --------------------------------------------------------------------------------
require_no_arguments "$@" || exit 2
start_group || exit 1
case_lib_units
finish_cases
