#!/usr/bin/env bash
# Self-test of H-01 (tests/host/h01-native-arch.sh) against the fake docker: matching image and container architectures pass; a wrong image, a wrong uname, an unknown daemon architecture and a platform warning in a build log each fail.
# - Run by run-all.sh; runs alone too.
# - Makes one work folder under TMPDIR and removes only that folder at exit.
# - Usage, from anywhere: bash tests/selftest/host/h01-native-arch.sh   (exit 0 = every case passes)
set -u
. "$(dirname "$0")/lib.sh"

# --------------------------------------------------------------------------------
# Cases of H-01, each run alone against the fake docker
# --------------------------------------------------------------------------------
case_h01_alone() {
  echo "--- H-01 on its own"
  reset_state
  make_fixture_run
  run_standalone "$WORK/out.h01" h01-native-arch.sh
  expect "H-01: matching image and container architectures pass" equals "$CHECK_RC" "0"
  expect "H-01: prints PASS: H-01" has_text "$WORK/out.h01" "PASS: H-01"
  run_standalone "$WORK/out.h01.amd" h01-native-arch.sh FAKE_CLAUDE_ARCH=amd64
  expect "H-01: an amd64 image on an aarch64 daemon fails" equals "$CHECK_RC" "1"
  expect "H-01: the wrong image is named" has_text "$WORK/out.h01.amd" "sbx-claude:local"
  run_standalone "$WORK/out.h01.uname" h01-native-arch.sh FAKE_UNAME=x86_64
  expect "H-01: a container uname that differs from the daemon fails" equals "$CHECK_RC" "1"
  run_standalone "$WORK/out.h01.unknown" h01-native-arch.sh FAKE_ARCH=riscv64
  expect "H-01: an unknown daemon architecture fails" equals "$CHECK_RC" "1"
  printf 'WARNING: requested image platform does not match the detected host platform\n' >"$FIXTURE/logs/build-base.log"
  run_standalone "$WORK/out.h01.warn" h01-native-arch.sh
  expect "H-01: a platform mismatch warning in a build log fails" equals "$CHECK_RC" "1"
  expect "H-01: the warning log is named" has_text "$WORK/out.h01.warn" "build-base.log"
}

# --------------------------------------------------------------------------------
# Main / Entry Point
# --------------------------------------------------------------------------------
require_no_arguments "$@" || exit 2
start_group || exit 1
case_h01_alone
finish_cases
