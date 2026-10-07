#!/usr/bin/env bash
# Self-test of the sandbox rules: the start rules pass on a clean copy and fail, naming the line, when working_dir is put back under the project folder; the docs rule passes on a clean copy and fails, naming the line, when an image comment promises that nothing is created or SANDBOX.md promises a good build.
# - Run by run-all.sh; runs alone too.
# - Runs the real tests/guard/start.sh and tests/guard/docs.sh inside a scratch copy of the tree, so a planted problem never touches the real files.
# - Makes one work folder under TMPDIR and removes only that folder at exit.
# - Usage, from anywhere: bash tests/selftest/guard/sandbox-rules.sh   (exit 0 = every case passes)
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
# Cases of the start rules: a clean copy and a working_dir under the project folder
# --------------------------------------------------------------------------------
case_start_rules() {
  echo "--- start rules"

  make_scratch_repo || return 1
  run_scratch_guard "$WORK/start-clean.out" start.sh
  expect "sandbox rules: a clean copy passes the start rules" equals "$GUARD_RC" 0

  make_scratch_repo || return 1
  edit_scratch_file compose.yml 's|^\( *working_dir: \).*$|\1"/home/sandbox/workspace/${SBX_NAME}"|' || return 1
  run_scratch_guard "$WORK/start-under.out" start.sh
  expect "sandbox rules: a working_dir under the project folder fails" has_text "$WORK/start-under.out" "FAIL: compose_starts_in_the_workspace"
  expect "sandbox rules: that working_dir line is named" has_text "$WORK/start-under.out" 'working_dir: "/home/sandbox/workspace/${SBX_NAME}"'
  expect "sandbox rules: a working_dir under the project folder exits non-zero" test "$GUARD_RC" -ne 0
}

# --------------------------------------------------------------------------------
# Cases of the docs rules: a clean copy, an image comment that promises nothing is created, and a doc that promises a good build
# --------------------------------------------------------------------------------
case_docs_rule() {
  echo "--- docs rule"

  make_scratch_repo || return 1
  edit_scratch_file base/Dockerfile 's/never creates anything on the Mac/may be asked not to create a folder on the Mac/' || return 1
  run_scratch_guard "$WORK/docs-clean.out" docs.sh
  expect "sandbox rules: an image comment without the promise passes the docs rule" equals "$GUARD_RC" 0

  make_scratch_repo || return 1
  printf '# - It never creates anything on the Mac.\n' >>"$WORK/repo/base/Dockerfile"
  run_scratch_guard "$WORK/docs-promise.out" docs.sh
  expect "sandbox rules: a promise that nothing is created fails" has_text "$WORK/docs-promise.out" "FAIL: docs_promise_only_what_happens"
  expect "sandbox rules: the promising line is named" has_text "$WORK/docs-promise.out" "never creates anything on the Mac"

  make_scratch_repo || return 1
  printf 'When it passes, the build is good.\n' >>"$WORK/repo/SANDBOX.md"
  run_scratch_guard "$WORK/docs-good-build.out" docs.sh
  expect "sandbox rules: a doc that promises a good build fails" has_text "$WORK/docs-good-build.out" "FAIL: docs_promise_only_what_happens"
  expect "sandbox rules: the good-build line is named" has_text "$WORK/docs-good-build.out" "When it passes, the build is good."
  expect "sandbox rules: a doc that promises a good build exits non-zero" test "$GUARD_RC" -ne 0
}

# --------------------------------------------------------------------------------
# Main / Entry Point
# --------------------------------------------------------------------------------
require_no_arguments "$@" || exit 2
start_group || exit 1
case_start_rules
case_docs_rule
finish_cases
