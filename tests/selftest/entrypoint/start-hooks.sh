#!/usr/bin/env bash
# Self-test of the start hook step: runs run_start_hooks from base/sbx-start-lib.sh on Linux against fixture hook folders.
# - Proves that an executable hook runs, that a hook that is not executable, fails, is a dangling link or is a fifo
#   stops the start before a later hook, and that folders, dotfiles and an empty folder are handled.
# - Run by run-all.sh; runs alone too.
# - Makes one work folder under TMPDIR and removes only that folder at exit.
# - Usage, from anywhere: bash tests/selftest/entrypoint/start-hooks.sh   (exit 0 = every case passes)
set -u
. "$(dirname "$0")/lib.sh"

# --------------------------------------------------------------------------------
# run_hooks DIR OUTFILE: sources the start library in a subshell, points it at DIR and runs the hooks; sets HOOKS_RC.
# --------------------------------------------------------------------------------
run_hooks() {
  ( . "$START_LIB"; hookDir=$1; run_start_hooks ) >"$2" 2>&1 </dev/null
  HOOKS_RC=$?
}

# --------------------------------------------------------------------------------
# write_hook FILE MARKER EXIT_CODE MODE: writes a small hook that creates MARKER and exits with EXIT_CODE.
# --------------------------------------------------------------------------------
write_hook() {
  printf '#!/bin/sh\ntouch "%s"\nexit %s\n' "$2" "$3" >"$1"
  chmod "$4" "$1"
}

# --------------------------------------------------------------------------------
# Case: an executable hook runs
# --------------------------------------------------------------------------------
case_executable_hook_runs() {
  local hooks=$WORK/executable/hooks marker=$WORK/executable/ran

  echo '--- an executable hook runs'
  mkdir -p "$hooks"
  write_hook "$hooks/10-ok" "$marker" 0 755

  run_hooks "$hooks" "$WORK/executable/out"

  expect "executable hook: the hooks step exits 0" equals "$HOOKS_RC" 0
  expect "executable hook: the hook ran" test -f "$marker"
}

# --------------------------------------------------------------------------------
# Case: a file that is not executable stops the start before a later hook
# --------------------------------------------------------------------------------
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

# --------------------------------------------------------------------------------
# Case: a hook that fails stops the start
# --------------------------------------------------------------------------------
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

# --------------------------------------------------------------------------------
# Case: a folder and a dotfile are skipped
# --------------------------------------------------------------------------------
case_folder_and_dotfile_skipped() {
  local hooks=$WORK/skipped/hooks marker=$WORK/skipped/ran

  echo '--- a folder and a dotfile are skipped'
  mkdir -p "$hooks/05-folder"
  write_hook "$hooks/.hidden" "$WORK/skipped/hidden-ran" 0 644
  write_hook "$hooks/10-ok" "$marker" 0 755

  run_hooks "$hooks" "$WORK/skipped/out"

  expect "skipped: the hooks step exits 0" equals "$HOOKS_RC" 0
  expect "skipped: the executable hook ran" test -f "$marker"
}

# --------------------------------------------------------------------------------
# Case: an empty folder is fine
# --------------------------------------------------------------------------------
case_empty_folder() {
  local hooks=$WORK/empty/hooks

  echo '--- an empty folder is fine'
  mkdir -p "$hooks"

  run_hooks "$hooks" "$WORK/empty/out"

  expect "empty folder: the hooks step exits 0" equals "$HOOKS_RC" 0
  expect "empty folder: nothing is printed" test ! -s "$WORK/empty/out"
}

# --------------------------------------------------------------------------------
# Case: a link to a file that is not executable stops the start
# --------------------------------------------------------------------------------
case_symlink_not_executable() {
  local hooks=$WORK/symlink/hooks

  echo '--- a link to a file that is not executable stops the start'
  mkdir -p "$hooks"
  write_hook "$WORK/symlink/target" "$WORK/symlink/ran" 0 644
  ln -s "$WORK/symlink/target" "$hooks/10-link"

  run_hooks "$hooks" "$WORK/symlink/out"

  expect "symlink: the hooks step exits 1" equals "$HOOKS_RC" 1
  expect "symlink: the error says not executable" has_text "$WORK/symlink/out" "is not executable"
}

# --------------------------------------------------------------------------------
# Case: a link that points nowhere stops the start before a later hook
# --------------------------------------------------------------------------------
case_dangling_link_stops() {
  local hooks=$WORK/dangling/hooks marker=$WORK/dangling/later-ran

  echo '--- a link that points nowhere stops the start'
  mkdir -p "$hooks"
  ln -s "$WORK/dangling/missing" "$hooks/10-dangling"
  write_hook "$hooks/20-later" "$marker" 0 755

  run_hooks "$hooks" "$WORK/dangling/out"

  expect "dangling link: the hooks step exits 1" equals "$HOOKS_RC" 1
  expect "dangling link: the error names the link" has_text "$WORK/dangling/out" "[sbx] ERROR: start hook $hooks/10-dangling is not a regular file; the container was not started."
  expect "dangling link: the later hook never ran" test ! -e "$marker"
}

# --------------------------------------------------------------------------------
# Case: a fifo stops the start before a later hook, without hanging
# --------------------------------------------------------------------------------
case_fifo_stops() {
  local hooks=$WORK/fifo/hooks marker=$WORK/fifo/later-ran

  echo '--- a fifo stops the start'
  mkdir -p "$hooks"
  mkfifo "$hooks/10-fifo"
  write_hook "$hooks/20-later" "$marker" 0 755

  run_hooks "$hooks" "$WORK/fifo/out"

  expect "fifo: the hooks step exits 1" equals "$HOOKS_RC" 1
  expect "fifo: the error names the fifo" has_text "$WORK/fifo/out" "[sbx] ERROR: start hook $hooks/10-fifo is not a regular file; the container was not started."
  expect "fifo: the later hook never ran" test ! -e "$marker"
}

# --------------------------------------------------------------------------------
# Main / Entry Point
# --------------------------------------------------------------------------------
require_no_arguments "$@" || exit 2
start_group || exit 1
case_executable_hook_runs
case_not_executable_stops
case_failing_hook_stops
case_folder_and_dotfile_skipped
case_empty_folder
case_symlink_not_executable
case_dangling_link_stops
case_fifo_stops
finish_cases
