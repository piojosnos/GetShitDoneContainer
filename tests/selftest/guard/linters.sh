#!/usr/bin/env bash
# ------------------------------------------------------------------------------
# Self-test of the linter rules: missing or failing fails, clean passes
# ------------------------------------------------------------------------------
# Usage: bash tests/selftest/guard/linters.sh (exit 0 = every case passes)
# The cases put fake tools on PATH, so they do not depend on the sandbox.
# ------------------------------------------------------------------------------
set -u
. "$(dirname "$0")/lib.sh"

# ------------------------------------------------------------------------------
# write_fake_linters STATUS: writes fake linters into WORK/fakebin
# ------------------------------------------------------------------------------
# Each fake prints "fake finding from NAME" and exits with STATUS.
# ------------------------------------------------------------------------------
write_fake_linters() {
  local status=$1
  local tool

  mkdir -p "$WORK/fakebin"

  for tool in shellcheck hadolint; do
    printf '#!/bin/bash\necho "fake finding from $(basename "$0")"\nexit %s\n' "$status" >"$WORK/fakebin/$tool"
    chmod 755 "$WORK/fakebin/$tool"
  done
}

# ------------------------------------------------------------------------------
# run_linters_group OUTFILE PATH_VALUE: runs the real group with that PATH
# ------------------------------------------------------------------------------
# Stdin is closed and all output goes to OUTFILE; sets LINTERS_RC.
# ------------------------------------------------------------------------------
run_linters_group() {
  LINTERS_RC=0
  env PATH="$2" bash "$REPO/tests/guard/linters.sh" >"$1" 2>&1 </dev/null || LINTERS_RC=$?
}

# ------------------------------------------------------------------------------
# case_missing_linters: with no linter on PATH, both rules fail
# ------------------------------------------------------------------------------
case_missing_linters() {
  local verdict=zero

  echo "--- missing linters"

  run_linters_group "$WORK/missing.out" "/usr/bin:/bin"

  if [ "$LINTERS_RC" -ne 0 ]; then
    verdict=nonzero
  fi

  expect "missing linters: shellcheck_passes fails" has_text "$WORK/missing.out" "FAIL: shellcheck_passes"
  expect "missing linters: shellcheck is named" has_text "$WORK/missing.out" "shellcheck is not installed"
  expect "missing linters: hadolint_passes fails" has_text "$WORK/missing.out" "FAIL: hadolint_passes"
  expect "missing linters: hadolint is named" has_text "$WORK/missing.out" "hadolint is not installed"
  expect "missing linters: the group exits non-zero" equals "$verdict" nonzero
}

# ------------------------------------------------------------------------------
# case_failing_linters: a linter that reports a problem fails its rule
# ------------------------------------------------------------------------------
case_failing_linters() {
  echo "--- failing linters"

  write_fake_linters 1
  run_linters_group "$WORK/failing.out" "$WORK/fakebin:/usr/bin:/bin"

  expect "failing linters: shellcheck_passes fails" has_text "$WORK/failing.out" "FAIL: shellcheck_passes"
  expect "failing linters: hadolint_passes fails" has_text "$WORK/failing.out" "FAIL: hadolint_passes"
  expect "failing linters: the shellcheck output is shown" has_text "$WORK/failing.out" "    fake finding from shellcheck"
  expect "failing linters: the hadolint output is shown" has_text "$WORK/failing.out" "    fake finding from hadolint"
}

# ------------------------------------------------------------------------------
# case_passing_linters: two clean linters pass both rules
# ------------------------------------------------------------------------------
case_passing_linters() {
  echo "--- passing linters"

  write_fake_linters 0
  run_linters_group "$WORK/passing.out" "$WORK/fakebin:/usr/bin:/bin"

  expect "passing linters: shellcheck_passes passes" has_text "$WORK/passing.out" "PASS: shellcheck_passes"
  expect "passing linters: hadolint_passes passes" has_text "$WORK/passing.out" "PASS: hadolint_passes"
  expect "passing linters: the group exits 0" equals "$LINTERS_RC" 0
}

# ------------------------------------------------------------------------------
# Main / Entry Point
# ------------------------------------------------------------------------------
require_no_arguments "$@" || exit 2
start_group || exit 1
case_missing_linters
case_failing_linters
case_passing_linters
finish_cases
