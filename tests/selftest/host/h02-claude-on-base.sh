#!/usr/bin/env bash
# Self-test of H-02 (tests/host/h02-claude-on-base.sh) against the fake docker: the Claude layers on top of the base layers pass; a differing layer and a Claude image with no layer of its own fail.
# - Run by run-all.sh; runs alone too.
# - Makes one work folder under TMPDIR and removes only that folder at exit.
# - Usage, from anywhere: bash tests/selftest/host/h02-claude-on-base.sh   (exit 0 = every case passes)
set -u
. "$(dirname "$0")/lib.sh"

# --------------------------------------------------------------------------------
# Cases of H-02, each run alone against the fake docker
# --------------------------------------------------------------------------------
case_h02_alone() {
  reset_state
  FIXTURE=""
  echo "--- H-02 on its own"
  run_standalone "$WORK/out.h02" h02-claude-on-base.sh
  expect "H-02: base layers under the Claude layers pass" equals "$CHECK_RC" "0"
  expect "H-02: prints PASS: H-02" has_text "$WORK/out.h02" "PASS: H-02"
  run_standalone "$WORK/out.h02.bad" h02-claude-on-base.sh FAKE_CLAUDE_LAYERS="sha256:b1 sha256:x9 sha256:c1"
  expect "H-02: a differing layer fails" equals "$CHECK_RC" "1"
  expect "H-02: a differing layer prints FAIL: H-02" has_text "$WORK/out.h02.bad" "FAIL: H-02"
  expect "H-02: a differing layer shows both layers" \
    has_text "$WORK/out.h02.bad" "sha256:b2"
  expect "H-02: a differing layer shows the Claude side too" \
    has_text "$WORK/out.h02.bad" "sha256:x9"
  run_standalone "$WORK/out.h02.same" h02-claude-on-base.sh FAKE_CLAUDE_LAYERS="sha256:b1 sha256:b2"
  expect "H-02: a Claude image with no layer of its own fails" failed_with "$CHECK_RC" "$WORK/out.h02.same" "no layer of its own"
}

# --------------------------------------------------------------------------------
# Main / Entry Point
# --------------------------------------------------------------------------------
require_no_arguments "$@" || exit 2
start_group || exit 1
case_h02_alone
finish_cases
