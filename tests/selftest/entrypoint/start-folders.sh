#!/usr/bin/env bash
# Self-test of the start folders: the real entrypoint runs end to end, and the folder steps of base/sbx-start-lib.sh are called one by one.
# - Proves that the command starts in the project folder and that a folder that cannot be entered stops the start.
# - Runs a copy of the real entrypoint and library; only the paths and the mount test are overridden.
# - Run by run-all.sh; runs alone too.
# - Makes one work folder under TMPDIR and removes only that folder at exit.
# - Usage, from anywhere: bash tests/selftest/entrypoint/start-folders.sh   (exit 0 = every case passes)
set -u
. "$(dirname "$0")/lib.sh"

# --------------------------------------------------------------------------------
# make_entry_copy: copies the entrypoint and the library into WORK/entry and points the library copy at WORK.
# --------------------------------------------------------------------------------
# Four lines are appended to the library copy: the workspace, the state folder, the hook folder
# and a mount test that says yes. The project folder demo, the state folder and an empty hook
# folder are made.
make_entry_copy() {
  mkdir -p "$WORK/entry" "$WORK/ws/demo" "$WORK/ws/state" "$WORK/hooks"

  cp "$ENTRY" "$WORK/entry/sbx-entrypoint"
  cp "$START_LIB" "$WORK/entry/sbx-start-lib.sh"

  {
    echo "ws=$WORK/ws"
    echo "state=$WORK/ws/state"
    echo "hookDir=$WORK/hooks"
    echo "is_mount() { return 0; }"
  } >>"$WORK/entry/sbx-start-lib.sh"
}

# --------------------------------------------------------------------------------
# copies_are_real: true when the entrypoint copy is the real entrypoint and the library copy minus its four appended lines is the real library.
# --------------------------------------------------------------------------------
copies_are_real() {
  local realLineCount

  realLineCount=$(( $(wc -l <"$START_LIB") ))

  cmp -s "$WORK/entry/sbx-entrypoint" "$ENTRY" &&
    head -n "$realLineCount" "$WORK/entry/sbx-start-lib.sh" | cmp -s - "$START_LIB"
}

# --------------------------------------------------------------------------------
# started_in RC OUTFILE FOLDER: true when the start exited 0 and the last output line is FOLDER.
# --------------------------------------------------------------------------------
started_in() {
  [ "$1" -eq 0 ] && [ "$(tail -n 1 "$2")" = "$3" ]
}

# --------------------------------------------------------------------------------
# stopped_before_command RC OUTFILE: true when the start exited 1, named the missing project folder and never ran the command.
# --------------------------------------------------------------------------------
stopped_before_command() {
  [ "$1" -eq 1 ] && has_text "$2" "(the project folder) is missing." && lacks_text "$2" "command-ran"
}

# --------------------------------------------------------------------------------
# Case: the copy under test is the real code
# --------------------------------------------------------------------------------
case_copy_is_real() {
  echo '--- the copy under test is the real entrypoint and library'
  make_entry_copy

  expect "entrypoint: the copy under test is the real entrypoint and library" copies_are_real
}

# --------------------------------------------------------------------------------
# Case: the command starts in the project folder
# --------------------------------------------------------------------------------
case_command_starts_in_project() {
  local startRc

  echo '--- the command starts in the project folder'
  make_entry_copy
  mkdir -p "$WORK/start"

  ( cd "$WORK" && SBX_NAME=demo bash "$WORK/entry/sbx-entrypoint" pwd -P ) >"$WORK/start/out" 2>&1 </dev/null
  startRc=$?

  expect "entrypoint: the command starts in the project folder" started_in "$startRc" "$WORK/start/out" "$WORK/ws/demo"
}

# --------------------------------------------------------------------------------
# Case: a missing project folder stops the start before the command
# --------------------------------------------------------------------------------
case_missing_project_stops_start() {
  local missingRc

  echo '--- a missing project folder stops the start before the command'
  make_entry_copy
  mkdir -p "$WORK/missing"

  ( cd "$WORK" && SBX_NAME=nosuch bash "$WORK/entry/sbx-entrypoint" echo command-ran ) >"$WORK/missing/out" 2>&1 </dev/null
  missingRc=$?

  expect "entrypoint: a missing project folder stops the start before the command" \
    stopped_before_command "$missingRc" "$WORK/missing/out"
}

# --------------------------------------------------------------------------------
# Case: a project folder that cannot be entered is refused
# --------------------------------------------------------------------------------
case_cannot_enter_project() {
  local enterRc

  echo '--- a project folder that cannot be entered is refused'
  mkdir -p "$WORK/enter"

  ( . "$START_LIB"; ws=$WORK/enter/no-workspace; SBX_NAME=demo; enter_project_folder ) >"$WORK/enter/out" 2>&1 </dev/null
  enterRc=$?

  expect "enter_project_folder: a missing project folder is refused" equals "$enterRc" 1
  expect "enter_project_folder: says it cannot enter the folder" has_text "$WORK/enter/out" "[sbx] ERROR: cannot enter"
}

# --------------------------------------------------------------------------------
# Case: the workspace check says what it checks
# --------------------------------------------------------------------------------
case_mount_wording() {
  local mountRc

  echo '--- the workspace check says what it checks'
  mkdir -p "$WORK/mount/plain"

  ( . "$START_LIB"; ws=$WORK/mount/plain; SBX_NAME=demo; check_workspace_mount ) >"$WORK/mount/out" 2>&1 </dev/null
  mountRc=$?

  expect "check_workspace_mount: a plain folder is refused" equals "$mountRc" 1
  expect "check_workspace_mount: says the workspace is not a mount point" has_text "$WORK/mount/out" "is not a mount point"
}

# --------------------------------------------------------------------------------
# Case: the self-test runs as a user the permission bits apply to
# --------------------------------------------------------------------------------
# Root can write anywhere, so the unwritable state case would prove nothing.
case_runs_as_non_root() {
  echo '--- the self-test runs as a non-root user'

  expect "start folders: the self-test runs as a non-root user" test "$(id -u)" -ne 0
}

# --------------------------------------------------------------------------------
# Case: an unwritable state folder is refused by name
# --------------------------------------------------------------------------------
case_unwritable_state() {
  local stateRc

  echo '--- an unwritable state folder is refused by name'
  mkdir -p "$WORK/ws-ro/demo" "$WORK/ws-ro/state"
  chmod 555 "$WORK/ws-ro/state"

  ( . "$START_LIB"; ws=$WORK/ws-ro; state=$ws/state; SBX_NAME=demo; check_project_and_state_folders ) >"$WORK/ws-ro/out" 2>&1 </dev/null
  stateRc=$?

  chmod 755 "$WORK/ws-ro/state"

  expect "check_project_and_state_folders: an unwritable state folder is refused" equals "$stateRc" 1
  expect "check_project_and_state_folders: the unwritable state folder is named" \
    has_text "$WORK/ws-ro/out" "$WORK/ws-ro/state is not writable by"
}

# --------------------------------------------------------------------------------
# Case: a * in the state folder list stays a literal name
# --------------------------------------------------------------------------------
case_literal_state_names() {
  echo '--- a * in the state folder list stays a literal name'
  mkdir -p "$WORK/cwd" "$WORK/ws-glob/state"
  : >"$WORK/cwd/aaa"

  ( cd "$WORK/cwd" && . "$START_LIB"; ws=$WORK/ws-glob; state=$ws/state; SBX_STATE_DIRS='*'; create_state_dirs ) >"$WORK/ws-glob/out" 2>&1 </dev/null

  expect "create_state_dirs: a * in SBX_STATE_DIRS is not expanded" test ! -e "$WORK/ws-glob/state/aaa"
  expect "create_state_dirs: the folder named * is made" test -d "$WORK/ws-glob/state/*"
}

# --------------------------------------------------------------------------------
# Main / Entry Point
# --------------------------------------------------------------------------------
require_no_arguments "$@" || exit 2
start_group || exit 1
case_copy_is_real
case_command_starts_in_project
case_missing_project_stops_start
case_cannot_enter_project
case_mount_wording
case_runs_as_non_root
case_unwritable_state
case_literal_state_names
finish_cases
