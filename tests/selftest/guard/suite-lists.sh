#!/usr/bin/env bash
# Self-test of the suite list rules: a group that is never run, a stale list entry, a missing list and a host check without a self-test group each fail the guard by name.
# - Run by run-all.sh; runs alone too.
# - Runs the real tests/guard/suites.sh inside a scratch copy of the tree, so a planted problem never touches the real files.
# - Makes one work folder under TMPDIR and removes only that folder at exit.
# - Usage, from anywhere: bash tests/selftest/guard/suite-lists.sh   (exit 0 = every case passes)
set -u
. "$(dirname "$0")/lib.sh"

# --------------------------------------------------------------------------------
# edit_scratch_file FILE SED_SCRIPT: rewrites FILE of the scratch copy with the sed script; returns 1 on failure.
# --------------------------------------------------------------------------------
edit_scratch_file() {
  local editFile=$WORK/repo/$1

  sed "$2" "$editFile" >"$editFile.edited" || return 1
  mv "$editFile.edited" "$editFile"
}

# --------------------------------------------------------------------------------
# Cases on a clean copy and on a group that is not named in its runner
# --------------------------------------------------------------------------------
case_unlisted_group() {
  echo "--- unlisted group"

  make_scratch_repo || return 1
  run_scratch_guard "$WORK/clean.out" suites.sh
  expect "suite lists: a clean copy passes" equals "$GUARD_RC" 0

  make_scratch_repo || return 1
  cp "$WORK/repo/tests/selftest/entrypoint/start-hooks.sh" "$WORK/repo/tests/selftest/entrypoint/extra-group.sh"
  run_scratch_guard "$WORK/unlisted.out" suites.sh
  expect "suite lists: a group missing from its list fails" equals "$GUARD_RC" 1
  expect "suite lists: the unlisted group is named" has_text "$WORK/unlisted.out" "tests/selftest/entrypoint/extra-group.sh is not named in tests/selftest/entrypoint/run-all.sh"
}

# --------------------------------------------------------------------------------
# Cases on a listed group that does not exist and on a runner without a list
# --------------------------------------------------------------------------------
case_broken_lists() {
  echo "--- stale entry and missing list"

  make_scratch_repo || return 1
  edit_scratch_file tests/selftest/bundle/run-all.sh 's/^groupList="\(.*\)"$/groupList="\1 no-such-group.sh"/' || return 1
  run_scratch_guard "$WORK/stale.out" suites.sh
  expect "suite lists: a listed group that does not exist fails" equals "$GUARD_RC" 1
  expect "suite lists: the missing group is named" has_text "$WORK/stale.out" "names no-such-group.sh, which does not exist"

  make_scratch_repo || return 1
  edit_scratch_file tests/guard/run-all.sh 's/^groupList="/groupNames="/' || return 1
  run_scratch_guard "$WORK/no-list.out" suites.sh
  expect "suite lists: a runner with no groupList line fails" equals "$GUARD_RC" 1
  expect "suite lists: the runner without a list is named" has_text "$WORK/no-list.out" "has no groupList line"
}

# --------------------------------------------------------------------------------
# Case on a host check that has no self-test group
# --------------------------------------------------------------------------------
case_host_check_without_self_test() {
  echo "--- host check without a self-test group"

  make_scratch_repo || return 1
  rm -f "$WORK/repo/tests/selftest/host/h04-nonroot-user.sh"
  edit_scratch_file tests/selftest/host/run-all.sh 's/ h04-nonroot-user\.sh//' || return 1
  run_scratch_guard "$WORK/no-self-test.out" suites.sh
  expect "suite lists: a host check with no self-test group fails" equals "$GUARD_RC" 1
  expect "suite lists: the host check without a self-test group is named" has_text "$WORK/no-self-test.out" "tests/host/h04-nonroot-user.sh has no self-test group"
}

# --------------------------------------------------------------------------------
# Main / Entry Point
# --------------------------------------------------------------------------------
require_no_arguments "$@" || exit 2
start_group || exit 1
case_unlisted_group
case_broken_lists
case_host_check_without_self_test
finish_cases
