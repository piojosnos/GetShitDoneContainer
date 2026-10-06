#!/usr/bin/env bash
# Self-test of H-14 (tests/host/h14-bundle-in-image.sh) against the fake docker: a bundle equal to the repo with root owners and no mount passes; drift, a sandbox owner, a writable path, a mount, bad managed settings and no test sandbox fail.
# - Run by run-all.sh; runs alone too.
# - Makes one work folder under TMPDIR and removes only that folder at exit.
# - Usage, from anywhere: bash tests/selftest/host/h14-bundle-in-image.sh   (exit 0 = every case passes)
set -u
. "$(dirname "$0")/lib.sh"

# --------------------------------------------------------------------------------
# Cases of H-14, each run alone against the fake docker
# --------------------------------------------------------------------------------
case_h14_alone() {
  echo "--- H-14 on its own"
  reset_state
  make_fixture_run
  run_standalone "$WORK/out.h14" h14-bundle-in-image.sh
  expect "H-14: a bundle equal to the repo with root owners and no mount passes" equals "$CHECK_RC" "0"
  expect "H-14: prints PASS: H-14" has_text "$WORK/out.h14" "PASS: H-14"
  expect "H-14: the copy from the image is in the run folder's logs" \
    diff -r -q "$REPO/best-practices" "$(ls -d "$FIXTURE"/logs/h14-bundle-* | head -n 1)"
  expect "H-14: docker cp reads /opt/sbx/best-practices from the test container" \
    has_match "$FAKE_LOG" 'ARGS: cp sbx-hosttest:/opt/sbx/best-practices .*/logs/h14-bundle-'
  run_standalone "$WORK/out.h14.drift" h14-bundle-in-image.sh FAKE_BUNDLE_DRIFT=1
  expect "H-14: an image copy with an extra file fails" equals "$CHECK_RC" "1"
  expect "H-14: the extra file is named" has_text "$WORK/out.h14.drift" "h14-drift.md"
  run_standalone "$WORK/out.h14.owner" h14-bundle-in-image.sh FAKE_BUNDLE_OWNER=sandbox
  expect "H-14: a bundle owned by sandbox fails" equals "$CHECK_RC" "1"
  expect "H-14: the bundle path is named" has_text "$WORK/out.h14.owner" "/opt/sbx/best-practices is"
  expect "H-14: the wrong owner is shown" has_text "$WORK/out.h14.owner" "sandbox:sandbox 755"
  run_standalone "$WORK/out.h14.writable" h14-bundle-in-image.sh FAKE_BUNDLE_WRITABLE=1
  expect "H-14: a path the sandbox user can write fails" equals "$CHECK_RC" "1"
  expect "H-14: the writable path is named" has_text "$WORK/out.h14.writable" "/opt/sbx/best-practices/rules/communication.md"
  run_standalone "$WORK/out.h14.mount" h14-bundle-in-image.sh FAKE_BUNDLE_MOUNT=1
  expect "H-14: a mount under /opt/sbx fails" equals "$CHECK_RC" "1"
  expect "H-14: the mount point is named" has_text "$WORK/out.h14.mount" "a mount sits under"
  run_standalone "$WORK/out.h14.json" h14-bundle-in-image.sh FAKE_MANAGED_BAD=1
  expect "H-14: managed settings that do not parse fail" equals "$CHECK_RC" "1"
  expect "H-14: the parse failure is named" has_text "$WORK/out.h14.json" "do not parse"
  reset_state
  FIXTURE=""
  run_standalone "$WORK/out.h14.none" h14-bundle-in-image.sh
  expect "H-14: no test sandbox fails" equals "$CHECK_RC" "1"
  expect "H-14: no test sandbox says to run run-all.sh first" has_text "$WORK/out.h14.none" "run-all.sh first"
}

# --------------------------------------------------------------------------------
# Main / Entry Point
# --------------------------------------------------------------------------------
require_no_arguments "$@" || exit 2
start_group || exit 1
case_h14_alone
finish_cases
