#!/usr/bin/env bash
# Self-test of H-22 (tests/host/h22-toolchain-in-base.sh) against the fake docker: a native toolchain at its pins passes; a missing tool, a foreign architecture, a stale version, a JDK that is not Temurin and a tool a login shell cannot find each fail.
# - Run by run-all.sh; runs alone too.
# - Makes one work folder under TMPDIR and removes only that folder at exit.
# - Usage, from anywhere: bash tests/selftest/host/h22-toolchain-in-base.sh   (exit 0 = every case passes)
set -u
. "$(dirname "$0")/lib.sh"

# --------------------------------------------------------------------------------
# Cases of H-22, each run alone against the fake docker
# --------------------------------------------------------------------------------
case_h22_alone() {
  echo "--- H-22 on its own"
  reset_state
  make_fixture_run
  run_standalone "$WORK/out.h22" h22-toolchain-in-base.sh
  expect "H-22: a native toolchain at its pins passes" equals "$CHECK_RC" "0"
  expect "H-22: prints PASS: H-22" has_text "$WORK/out.h22" "PASS: H-22"
  expect "H-22: the base probe runs in a throwaway sbx-base:local container" \
    has_match "$FAKE_LOG" 'ARGS: run --rm --entrypoint bash sbx-base:local -c '
  expect "H-22: the sandbox probe runs in a login shell in the project folder" \
    has_match "$FAKE_LOG" 'ARGS: exec -w /home/sandbox/workspace/hosttest sbx-hosttest bash -lc '

  reset_state
  make_fixture_run
  run_standalone "$WORK/out.h22.mvn" h22-toolchain-in-base.sh FAKE_TOOL_MISSING=mvn
  expect "H-22: a missing Maven fails" failed_with "$CHECK_RC" "$WORK/out.h22.mvn" "mvn is missing"

  run_standalone "$WORK/out.h22.jq" h22-toolchain-in-base.sh FAKE_TOOL_MISSING=jq
  expect "H-22: a missing jq fails" failed_with "$CHECK_RC" "$WORK/out.h22.jq" "jq is missing"

  run_standalone "$WORK/out.h22.python" h22-toolchain-in-base.sh FAKE_TOOL_MISSING=python3
  expect "H-22: a missing Python fails" failed_with "$CHECK_RC" "$WORK/out.h22.python" "python3 is missing"

  run_standalone "$WORK/out.h22.elf" h22-toolchain-in-base.sh FAKE_TOOL_ELF=3e00
  expect "H-22: a foreign architecture fails" failed_with "$CHECK_RC" "$WORK/out.h22.elf" "expected b700"

  run_standalone "$WORK/out.h22.stale" h22-toolchain-in-base.sh FAKE_TOOL_STALE=node
  expect "H-22: a Node that is not the pin fails" failed_with "$CHECK_RC" "$WORK/out.h22.stale" "the pin is v"

  run_standalone "$WORK/out.h22.vendor" h22-toolchain-in-base.sh "FAKE_JAVA_VENDOR=OpenJDK Runtime Environment (build fake)"
  expect "H-22: a JDK that is not Temurin fails" failed_with "$CHECK_RC" "$WORK/out.h22.vendor" "Temurin"

  run_standalone "$WORK/out.h22.login" h22-toolchain-in-base.sh FAKE_LOGIN_MISSING=java
  expect "H-22: a tool a login shell cannot find fails" \
    failed_with "$CHECK_RC" "$WORK/out.h22.login" "login shell in the sandbox: java is missing"
  expect "H-22: the base image is not blamed for a login shell problem" lacks_text "$WORK/out.h22.login" "sbx-base:local: java is missing"

  reset_state
  FIXTURE=""
  run_standalone "$WORK/out.h22.none" h22-toolchain-in-base.sh
  expect "H-22: no test sandbox fails" equals "$CHECK_RC" "1"
  expect "H-22: no test sandbox says to run run-all.sh first" has_text "$WORK/out.h22.none" "run-all.sh first"
}

# --------------------------------------------------------------------------------
# Main / Entry Point
# --------------------------------------------------------------------------------
require_no_arguments "$@" || exit 2
start_group || exit 1
case_h22_alone
finish_cases
