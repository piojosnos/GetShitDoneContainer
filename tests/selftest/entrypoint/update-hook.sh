#!/usr/bin/env bash
# ------------------------------------------------------------------------------
# Self-test of cursor/start.d/02-no-self-update in a temp folder
# ------------------------------------------------------------------------------
# Usage: bash tests/selftest/entrypoint/update-hook.sh (exit 0 = all pass)
# Run by run-all.sh; its one work folder under TMPDIR is removed at exit.
# ------------------------------------------------------------------------------
set -u
. "$(dirname "$0")/lib.sh"

# ------------------------------------------------------------------------------
# run_update_hook CONFIG_DIR NAME: runs the hook, sets HOOK_RC
# ------------------------------------------------------------------------------
# Output goes to WORK/NAME.out and NAME.err.
# ------------------------------------------------------------------------------
run_update_hook() {
  env CURSOR_CONFIG_DIR="$1" bash "$REPO/cursor/start.d/02-no-self-update" >"$WORK/$2.out" 2>"$WORK/$2.err" </dev/null
  HOOK_RC=$?
}

# ------------------------------------------------------------------------------
# Case: a first start writes the static channel and prints one line
# ------------------------------------------------------------------------------
case_first_start() {
  local oneLine="[sbx] Cursor self-update off (static channel)"

  echo '--- a first start'
  run_update_hook "$WORK/first/cfg" first

  expect "update hook: a first start writes the static channel and one line" equals "$HOOK_RC:$(jq -r .channel "$WORK/first/cfg/cli-config.json"):$(cat "$WORK/first.out"):$(wc -c <"$WORK/first.err" | tr -d ' ')" "0:static:$oneLine:0"
}

# ------------------------------------------------------------------------------
# Case: a file the CLI wrote keeps its other keys
# ------------------------------------------------------------------------------
case_keeps_other_keys() {
  echo '--- a file with other keys'
  mkdir -p "$WORK/keys/cfg"
  printf '{"version":1,"permissions":{"allow":["Shell(ls)"]}}\n' >"$WORK/keys/cfg/cli-config.json"
  run_update_hook "$WORK/keys/cfg" keys

  expect "update hook: a file the CLI wrote keeps its other keys" jq -e '.version == 1 and .permissions.allow[0] == "Shell(ls)" and .channel == "static"' "$WORK/keys/cfg/cli-config.json" >/dev/null
}

# ------------------------------------------------------------------------------
# Case: a second run changes nothing
# ------------------------------------------------------------------------------
case_rerun() {
  echo '--- a rerun'
  run_update_hook "$WORK/rerun/cfg" rerun-first
  cp "$WORK/rerun/cfg/cli-config.json" "$WORK/rerun-before.json"
  run_update_hook "$WORK/rerun/cfg" rerun

  expect "update hook: a rerun leaves the file as it was" cmp -s "$WORK/rerun-before.json" "$WORK/rerun/cfg/cli-config.json"
}

# ------------------------------------------------------------------------------
# Case: a file that is not valid JSON stops the start and stays as it was
# ------------------------------------------------------------------------------
case_invalid_json() {
  local configFile=$WORK/invalid/cfg/cli-config.json

  echo '--- invalid JSON'
  mkdir -p "$WORK/invalid/cfg"
  printf '{not json\n' >"$configFile"
  run_update_hook "$WORK/invalid/cfg" invalid

  expect "update hook: invalid JSON stops the start and the file stays as it was" equals "$HOOK_RC:$(grep -Fc '[sbx] ERROR:' "$WORK/invalid.err"):$(grep -Fc "$configFile" "$WORK/invalid.err"):$(cat "$configFile"):$(test -e "$configFile.tmp" && echo tmp)" "1:1:1:{not json:"
}

# ------------------------------------------------------------------------------
# Case: an empty config folder variable stops the start
# ------------------------------------------------------------------------------
case_empty_variable() {
  echo '--- an empty CURSOR_CONFIG_DIR'
  run_update_hook "" empty

  expect "update hook: an empty CURSOR_CONFIG_DIR stops the start" equals "$HOOK_RC:$(cat "$WORK/empty.err")" "1:[sbx] ERROR: CURSOR_CONFIG_DIR is not set."
}

# ------------------------------------------------------------------------------
# Main / Entry Point
# ------------------------------------------------------------------------------
require_no_arguments "$@" || exit 2
start_group || exit 1
case_first_start
case_keeps_other_keys
case_rerun
case_invalid_json
case_empty_variable
finish_cases
