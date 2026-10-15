#!/usr/bin/env bash
# ------------------------------------------------------------------------------
# Self-test of the guard helpers: nowhere_matches fails loudly
# ------------------------------------------------------------------------------
# Usage: bash tests/selftest/guard/helpers.sh (exit 0 = every case passes)
# One work folder under TMPDIR, removed at exit; stdin is closed in every case.
# ------------------------------------------------------------------------------
set -u
. "$(dirname "$0")/lib.sh"

# ------------------------------------------------------------------------------
# guard_eval SNIPPET: runs SNIPPET after sourcing the real guard library
# ------------------------------------------------------------------------------
guard_eval() {
  ( . "$REPO/tests/guard/lib.sh"; eval "$1" )
}

# ------------------------------------------------------------------------------
# case_nowhere_matches: missing file, empty glob, no file, clean file, hit
# ------------------------------------------------------------------------------
case_nowhere_matches() {
  local missingFile=$WORK/no-such-file.txt
  local emptyFolder=$WORK/empty-folder
  local missingStatus=0
  local globStatus=0
  local noFileStatus=0
  local cleanStatus=0
  local hitStatus=0
  local hitReported

  echo "--- nowhere_matches"

  mkdir "$emptyFolder"
  printf 'clean\n' >"$WORK/clean.txt"
  printf 'docker run\n' >"$WORK/hit.txt"

  guard_eval "nowhere_matches docker $missingFile" >"$WORK/missing.out" 2>&1 </dev/null || missingStatus=$?
  guard_eval "nowhere_matches docker $emptyFolder/*.sh" >"$WORK/glob.out" 2>&1 </dev/null || globStatus=$?
  guard_eval "nowhere_matches docker" >"$WORK/nofile.out" 2>&1 </dev/null || noFileStatus=$?
  guard_eval "nowhere_matches docker $WORK/clean.txt" >"$WORK/clean.out" 2>&1 </dev/null || cleanStatus=$?
  guard_eval "nowhere_matches docker $WORK/hit.txt" >"$WORK/hit.out" 2>&1 </dev/null || hitStatus=$?

  expect "nowhere_matches: a missing file fails the rule" equals "$missingStatus" 1
  expect "nowhere_matches: the missing file is named" has_text "$WORK/missing.out" "$missingFile"
  expect "nowhere_matches: a glob that matched nothing fails the rule" equals "$globStatus" 1
  expect "nowhere_matches: no file at all fails the rule" equals "$noFileStatus" 1
  expect "nowhere_matches: a clean file passes" equals "$cleanStatus" 0

  hitReported=no

  if [ "$hitStatus" -eq 1 ] && has_text "$WORK/hit.out" "docker run"; then
    hitReported=yes
  fi

  expect "nowhere_matches: a hit fails and prints the line" equals "$hitReported" yes
}

# ------------------------------------------------------------------------------
# Main / Entry Point
# ------------------------------------------------------------------------------
require_no_arguments "$@" || exit 2
start_group || exit 1
case_nowhere_matches
finish_cases
