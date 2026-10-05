#!/usr/bin/env bash
# Self-test for base/sbx-entrypoint: runs its start hooks step on Linux against fixture hook folders.
# - Sources the script in a subshell, so no mount and no Docker are needed.
# - Also checks that the script runs its start checks when executed and none when sourced.
# - Makes one work folder under TMPDIR and removes only that folder at exit.
# - Usage, from anywhere: bash tests/entrypoint-selftest.sh   (exit 0 = every case passes)
set -u
cd "$(dirname "$0")/.." || exit 1
REPO=$(pwd -P)

ENTRY=$REPO/base/sbx-entrypoint
FAILS=0

# --------------------------------------------------------------------------------
# Makes the work folder and removes it, and only it, at exit
# --------------------------------------------------------------------------------
make_work_folder() {
  WORK=$(mktemp -d "${TMPDIR:-/tmp}/sbx-entrytest.XXXXXX") || exit 1
  WORK=$(cd "$WORK" && pwd -P)

  trap cleanup_work EXIT
  trap 'exit 130' INT TERM
}

# cleanup_work: removes the work folder made above, and only that.
cleanup_work() {
  case "$WORK" in
    */sbx-entrytest.*) rm -rf "$WORK" ;;
  esac
}

# --------------------------------------------------------------------------------
# Helpers the cases share
# --------------------------------------------------------------------------------

# expect NAME COMMAND...: PASS when the command succeeds.
expect() {
  local name=$1

  shift

  if "$@"; then
    echo "PASS: $name"
  else
    echo "FAIL: $name"
    FAILS=$((FAILS + 1))
  fi
}

# equals A B: true if the two strings are equal.
equals() { [ "$1" = "$2" ]; }

# has_text FILE TEXT: true if FILE contains TEXT.
has_text() { grep -Fq -- "$2" "$1"; }

# lacks_text FILE TEXT: true if FILE does not contain TEXT.
lacks_text() { ! grep -Fq -- "$2" "$1"; }

# run_hooks DIR OUTFILE: sources the entrypoint in a subshell, points it at DIR and runs the hooks; sets HOOKS_RC.
run_hooks() {
  ( . "$ENTRY"; hookDir=$1; run_start_hooks ) >"$2" 2>&1 </dev/null
  HOOKS_RC=$?
}

# write_hook FILE MARKER EXIT_CODE MODE: writes a small hook that creates MARKER and exits with EXIT_CODE.
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
# Case: sourcing the script runs no start step
# --------------------------------------------------------------------------------
case_sourcing_runs_nothing() {
  local sourceRc

  echo '--- sourcing the script runs no start step'
  mkdir -p "$WORK/sourced"

  ( . "$ENTRY" ) >"$WORK/sourced/out" 2>&1 </dev/null
  sourceRc=$?

  expect "sourced: the script exits 0" equals "$sourceRc" 0
  expect "sourced: nothing is printed" test ! -s "$WORK/sourced/out"
}

# --------------------------------------------------------------------------------
# Case: executing the script runs the start checks and not the command
# --------------------------------------------------------------------------------
case_direct_run_checks() {
  local directRc

  echo '--- executing the script runs the start checks'
  mkdir -p "$WORK/direct"

  env -u SBX_NAME bash "$ENTRY" echo entrypoint-command-ran >"$WORK/direct/out" 2>&1 </dev/null
  directRc=$?

  expect "direct run: the script exits 1" equals "$directRc" 1
  expect "direct run: a start check printed [sbx] ERROR" has_text "$WORK/direct/out" "[sbx] ERROR:"
  expect "direct run: the command never ran" lacks_text "$WORK/direct/out" "entrypoint-command-ran"
}

# --------------------------------------------------------------------------------
# Prints the summary and exits 0 only when every case passed
# --------------------------------------------------------------------------------
report_and_exit() {
  if [ "$FAILS" -eq 0 ]; then
    echo "All cases pass."
    exit 0
  fi

  echo "$FAILS case(s) failed."
  exit 1
}

# --------------------------------------------------------------------------------
# Main / Entry Point
# --------------------------------------------------------------------------------
make_work_folder
case_executable_hook_runs
case_not_executable_stops
case_failing_hook_stops
case_folder_and_dotfile_skipped
case_empty_folder
case_symlink_not_executable
case_dangling_link_stops
case_fifo_stops
case_sourcing_runs_nothing
case_direct_run_checks
report_and_exit
