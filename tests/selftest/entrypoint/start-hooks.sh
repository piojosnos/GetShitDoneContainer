#!/usr/bin/env bash
# ------------------------------------------------------------------------------
# Self-test of the start hook step in base/sbx-start-lib.sh
# ------------------------------------------------------------------------------
# Usage: bash tests/selftest/entrypoint/start-hooks.sh (exit 0 = all pass)
# Run by run-all.sh; its one work folder under TMPDIR is removed at exit.
# ------------------------------------------------------------------------------
set -u
. "$(dirname "$0")/lib.sh"

# ------------------------------------------------------------------------------
# run_hooks DIR OUTFILE: runs the start hooks found in DIR, sets HOOKS_RC
# ------------------------------------------------------------------------------
run_hooks() {
  ( . "$START_LIB"; hookDir=$1; run_start_hooks ) >"$2" 2>&1 </dev/null
  HOOKS_RC=$?
}

# ------------------------------------------------------------------------------
# write_hook FILE MARKER EXIT_CODE MODE: writes a hook that makes MARKER
# ------------------------------------------------------------------------------
write_hook() {
  printf '#!/bin/sh\ntouch "%s"\nexit %s\n' "$2" "$3" >"$1"
  chmod "$4" "$1"
}

# ------------------------------------------------------------------------------
# Case: an executable hook runs
# ------------------------------------------------------------------------------
case_executable_hook_runs() {
  local hooks=$WORK/executable/hooks marker=$WORK/executable/ran

  echo '--- an executable hook runs'
  mkdir -p "$hooks"
  write_hook "$hooks/10-ok" "$marker" 0 755

  run_hooks "$hooks" "$WORK/executable/out"

  expect "executable hook: the hooks step exits 0" equals "$HOOKS_RC" 0
  expect "executable hook: the hook ran" test -f "$marker"
}

# ------------------------------------------------------------------------------
# Case: a file that is not executable stops the start before a later hook
# ------------------------------------------------------------------------------
case_not_executable_stops() {
  local hooks=$WORK/notexec/hooks marker=$WORK/notexec/later-ran

  echo '--- a file that is not executable stops the start'
  mkdir -p "$hooks"
  write_hook "$hooks/10-not-executable" "$WORK/notexec/first-ran" 0 644
  write_hook "$hooks/20-later" "$marker" 0 755

  run_hooks "$hooks" "$WORK/notexec/out"

  expect "not executable: the hooks step exits 1" equals "$HOOKS_RC" 1
  expect "not executable: the error names the file" has_text "$WORK/notexec/out" "[sbx] ERROR: start hook $hooks/10-not-executable is not executable; the container was not started."
  expect "not executable: the later hook never ran" test ! -e "$marker"
}

# ------------------------------------------------------------------------------
# Case: a hook that fails stops the start
# ------------------------------------------------------------------------------
case_failing_hook_stops() {
  local hooks=$WORK/failing/hooks marker=$WORK/failing/later-ran

  echo '--- a failing hook stops the start'
  mkdir -p "$hooks"
  write_hook "$hooks/10-fails" "$WORK/failing/first-ran" 3 755
  write_hook "$hooks/20-later" "$marker" 0 755

  run_hooks "$hooks" "$WORK/failing/out"

  expect "failing hook: the hooks step exits 1" equals "$HOOKS_RC" 1
  expect "failing hook: the error says it failed" has_text "$WORK/failing/out" "[sbx] ERROR: start hook $hooks/10-fails failed; the container was not started."
  expect "failing hook: the later hook never ran" test ! -e "$marker"
}

# ------------------------------------------------------------------------------
# Main / Entry Point
# ------------------------------------------------------------------------------
require_no_arguments "$@" || exit 2
start_group || exit 1
case_executable_hook_runs
case_not_executable_stops
case_failing_hook_stops
finish_cases
