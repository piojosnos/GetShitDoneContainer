#!/usr/bin/env bash
# ------------------------------------------------------------------------------
# Self-test of the start folders and the sandbox name rule
# ------------------------------------------------------------------------------
# Usage: bash tests/selftest/entrypoint/start-folders.sh (exit 0 = all pass)
# Run by run-all.sh; its one work folder under TMPDIR is removed at exit.
# ------------------------------------------------------------------------------
set -u
. "$(dirname "$0")/lib.sh"

# ------------------------------------------------------------------------------
# make_entry_copy: copies the entrypoint and library into WORK/entry
# ------------------------------------------------------------------------------
# Four lines are appended to the library copy: the workspace, state and hook
# folders and a mount test that says yes. The folder demo is made.
# ------------------------------------------------------------------------------
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

# ------------------------------------------------------------------------------
# started_in RC OUTFILE FOLDER: true when the start exited 0 and ran in FOLDER
# ------------------------------------------------------------------------------
started_in() {
  [ "$1" -eq 0 ] && [ "$(tail -n 1 "$2")" = "$3" ]
}

# ------------------------------------------------------------------------------
# stopped_before_command RC OUTFILE: true when a missing folder stops the start
# ------------------------------------------------------------------------------
stopped_before_command() {
  [ "$1" -eq 1 ] && has_text "$2" "(the project folder) is missing." && lacks_text "$2" "command-ran"
}

# ------------------------------------------------------------------------------
# start_with_name NAME OUTFILE: starts a project folder named NAME, sets NAME_RC
# ------------------------------------------------------------------------------
# The command prints command-ran, then its folder as the last line.
# A name such as ../x makes its folder next to the workspace, under WORK.
# ------------------------------------------------------------------------------
start_with_name() {
  make_entry_copy
  mkdir -p "$WORK/ws/$1" "$WORK/name"

  ( cd "$WORK" && SBX_NAME=$1 bash "$WORK/entry/sbx-entrypoint" sh -c 'echo command-ran; pwd -P' ) >"$2" 2>&1 </dev/null
  NAME_RC=$?
}

# ------------------------------------------------------------------------------
# refused_by_name_rule RC OUTFILE: true when the name error stopped the start
# ------------------------------------------------------------------------------
refused_by_name_rule() {
  [ "$1" -eq 1 ] && has_text "$2" "[sbx] ERROR: SBX_NAME" && lacks_text "$2" "command-ran"
}

# ------------------------------------------------------------------------------
# Case: the command starts in the project folder
# ------------------------------------------------------------------------------
case_command_starts_in_project() {
  local startRc

  echo '--- the command starts in the project folder'
  make_entry_copy
  mkdir -p "$WORK/start"

  ( cd "$WORK" && SBX_NAME=demo bash "$WORK/entry/sbx-entrypoint" pwd -P ) >"$WORK/start/out" 2>&1 </dev/null
  startRc=$?

  expect "entrypoint: the command starts in the project folder" started_in "$startRc" "$WORK/start/out" "$WORK/ws/demo"
}

# ------------------------------------------------------------------------------
# Case: a missing project folder stops the start before the command
# ------------------------------------------------------------------------------
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

# ------------------------------------------------------------------------------
# Case: nested state folders from SBX_STATE_DIRS are made
# ------------------------------------------------------------------------------
case_nested_state_folders() {
  local nestedRc
  local folder
  local missing=""
  local nestedMade=1

  echo '--- nested state folders from SBX_STATE_DIRS are created'
  make_entry_copy
  mkdir -p "$WORK/nested"

  ( cd "$WORK" && SBX_NAME=demo SBX_STATE_DIRS="cache/npm cache/uv m2 claude" bash "$WORK/entry/sbx-entrypoint" true ) >"$WORK/nested/out" 2>&1 </dev/null
  nestedRc=$?

  for folder in cache/npm cache/uv m2 claude shell gh git; do
    if [ ! -d "$WORK/ws/state/$folder" ]; then
      missing="$missing $folder"
    fi
  done

  if [ "$nestedRc" -eq 0 ] && [ -z "$missing" ]; then
    nestedMade=0
  fi

  expect "entrypoint: nested state folders from SBX_STATE_DIRS are created" equals "$nestedMade" 0
}

# ------------------------------------------------------------------------------
# Case: the sandbox name rule decides whether the start goes on
# ------------------------------------------------------------------------------
case_name_rule() {
  local tooLongName
  local ruleText

  echo '--- the sandbox name rule decides whether the start goes on'
  ruleText='starts with a lowercase letter, then lowercase letters, digits or hyphens, 31 characters at most'
  tooLongName=a$(printf 'b%.0s' $(seq 1 31))

  start_with_name a "$WORK/name/one-letter.out"
  expect "entrypoint: one letter starts (a)" started_in "$NAME_RC" "$WORK/name/one-letter.out" "$WORK/ws/a"

  start_with_name my-project "$WORK/name/my-project.out"
  expect "entrypoint: my-project starts" started_in "$NAME_RC" "$WORK/name/my-project.out" "$WORK/ws/my-project"

  start_with_name HostTest "$WORK/name/upper.out"
  expect "entrypoint: an uppercase letter is refused (HostTest)" refused_by_name_rule "$NAME_RC" "$WORK/name/upper.out"

  start_with_name my_project "$WORK/name/underscore.out"
  expect "entrypoint: an underscore is refused (my_project)" refused_by_name_rule "$NAME_RC" "$WORK/name/underscore.out"

  start_with_name ../x "$WORK/name/path.out"
  expect "entrypoint: a path is refused (../x)" refused_by_name_rule "$NAME_RC" "$WORK/name/path.out"

  start_with_name "$tooLongName" "$WORK/name/too-long.out"
  expect "entrypoint: a name of 32 characters is refused" refused_by_name_rule "$NAME_RC" "$WORK/name/too-long.out"

  start_with_name state "$WORK/name/state.out"
  expect "entrypoint: the state folder name is refused (state)" refused_by_name_rule "$NAME_RC" "$WORK/name/state.out"

  start_with_name best-practices "$WORK/name/best-practices.out"
  expect "entrypoint: the clone folder name is refused (best-practices)" refused_by_name_rule "$NAME_RC" "$WORK/name/best-practices.out"
  expect "entrypoint: a taken name says so" has_text "$WORK/name/best-practices.out" "is taken:"

  expect "entrypoint: the name error names SBX_NAME and the value" has_text "$WORK/name/upper.out" 'SBX_NAME "HostTest"'
  expect "entrypoint: the name error states the rule in plain words" has_text "$WORK/name/upper.out" "$ruleText"
  expect "entrypoint: the name error gives a valid example" has_text "$WORK/name/upper.out" "Example: my-project."
}

# ------------------------------------------------------------------------------
# Main / Entry Point
# ------------------------------------------------------------------------------
require_no_arguments "$@" || exit 2
start_group || exit 1
case_command_starts_in_project
case_missing_project_stops_start
case_name_rule
case_nested_state_folders
finish_cases
