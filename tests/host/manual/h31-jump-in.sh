#!/usr/bin/env bash
# ------------------------------------------------------------------------------
# H-31 helper: sbx-shell opens a real shell; sbx-claude there stays logged in
# ------------------------------------------------------------------------------
# Usage: bash tests/host/manual/h31-jump-in.sh
# Needs a terminal. It logs in to Claude itself, in its own registered sandbox
# folder, so it needs no earlier login. Exit 0 = PASS.
# ------------------------------------------------------------------------------
set -u

. "$(dirname "$0")/lib-manual.sh"
require_terminal

. "$(dirname "$0")/../lib.sh"
host_init
. "$(dirname "$0")/../lib-sbx.sh"

sbxDir=""
sbxPath=""
sbxStatus=0

# ------------------------------------------------------------------------------
# Registers the helper's own sandbox; FAIL and return 1 if it fails
# ------------------------------------------------------------------------------
# It has no container yet, so the first sbx-shell has to start it.
# ------------------------------------------------------------------------------
prepare() {
  require_test_sandbox H-31 || return 1
  sbx_test_setup H-31 h31m || return 1

  if ! compose_down >"$RUN/logs/h31m-down.log" 2>&1; then
    fail H-31 "compose down failed before the helper; log: $RUN/logs/h31m-down.log"
    return 1
  fi

  run_sbx h31m-add sbx-add hosttest "$sbxDir"

  if [ "$sbxStatus" -ne 0 ]; then
    fail H-31 "sbx-add exited $sbxStatus; log: $RUN/logs/h31m-add.err"
    restore_test_sandbox h31m
    return 1
  fi
}

# ------------------------------------------------------------------------------
# Opens the first shell, asks for the login, then checks the login and folder
# ------------------------------------------------------------------------------
first_jump_in() {
  printf '\nsbx-shell starts the helper sandbox first (it has no container yet),\n'
  printf 'then opens a shell. In that shell:\n'
  printf '  1. run pwd; it prints /home/sandbox/workspace/hosttest\n'
  printf '  2. run sbx-claude, log in with a claude.ai account, send one message,\n'
  printf '     then type /exit\n'
  printf '  3. type exit\n\n'
  env PATH="$sbxPath" sbx-shell hosttest
  printf '\n'

  if [ "$(sandbox_field '{{.State.Running}}')" != "true" ]; then
    add_problem "$CONTAINER is not running after sbx-shell"
  fi

  count_result H-31 "the sandbox does not run after sbx-shell" \
    "sbx-shell started the helper's sandbox"
  add_login_problem
  count_result H-31 "claude auth status shows no login after sbx-claude in the sbx-shell shell" \
    'claude auth status shows "loggedIn": true after the login in the sbx-shell shell'
  ask_judgment H-31 "Did the shell open in /home/sandbox/workspace/hosttest?" \
    "the shell opened in the project folder" \
    "the shell did not open in the project folder"
}

# ------------------------------------------------------------------------------
# Stops the sandbox, opens a new shell and asks whether Claude is logged in
# ------------------------------------------------------------------------------
second_jump_in() {
  run_sbx h31m-stop sbx-stop hosttest

  if [ "$sbxStatus" -ne 0 ]; then
    add_problem "sbx-stop exited $sbxStatus; log: $RUN/logs/h31m-stop.err"
  fi

  printf '\nsbx-shell starts the stopped sandbox again and opens a shell. In it:\n'
  printf '  1. run sbx-claude; Claude must open without asking you to log in\n'
  printf '  2. type /exit, then type exit\n\n'
  env PATH="$sbxPath" sbx-shell hosttest
  printf '\n'
  ask_judgment H-31 "Did sbx-claude open Claude already logged in, with no login prompt?" \
    "sbx-claude in a new sbx-shell shell started Claude already logged in" \
    "sbx-claude asked for a login again"
}

# ------------------------------------------------------------------------------
# Puts the test sandbox back on the run folder
# ------------------------------------------------------------------------------
restore() {
  restore_test_sandbox h31m
  count_result H-31 "the test sandbox did not come back on the run folder" \
    "the test sandbox runs on the run folder again"
  printf 'The run folder now also holds the Claude login of this helper.\n'
  printf 'The cleanup command that run-all.sh printed removes it.\n'
}

# ------------------------------------------------------------------------------
# Main / Entry Point
# ------------------------------------------------------------------------------
require_no_arguments "$@" || exit 2
prepare || exit 1
first_jump_in
second_jump_in
restore
exit_with_result
