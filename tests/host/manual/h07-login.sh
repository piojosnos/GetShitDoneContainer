#!/usr/bin/env bash
# ------------------------------------------------------------------------------
# H-07 helper: log in to Claude in the test sandbox, then check the login
# ------------------------------------------------------------------------------
# Usage: bash tests/host/manual/h07-login.sh (exit 0 = all PASS)
# Needs a terminal and the test sandbox that tests/host/run-all.sh leaves up.
# ------------------------------------------------------------------------------
set -u

. "$(dirname "$0")/lib-manual.sh"
require_terminal

. "$(dirname "$0")/../lib.sh"
host_init

stateDir="$RUN/state/claude"

# ------------------------------------------------------------------------------
# Opens Claude in the test sandbox for the login
# ------------------------------------------------------------------------------
run_login() {
  printf 'Claude opens next, inside the test sandbox.\n'
  printf '  1. Log in with a claude.ai account.\n'
  printf '  2. Send one message (for example: say hi) and wait for the answer.\n'
  printf '     Claude saves a conversation only once a message is sent; the GSD bump helper resumes it.\n'
  printf '  3. Type /exit to come back here.\n\n'
  run_claude
  printf '\n'
}

# ------------------------------------------------------------------------------
# Checks the login files reached the state folder on the Mac
# ------------------------------------------------------------------------------
check_login_files() {
  local stateFile

  for stateFile in .claude.json .credentials.json; do
    if [ ! -f "$stateDir/$stateFile" ]; then
      add_problem "missing on the Mac: $stateDir/$stateFile"
    fi
  done

  if [ ! -d "$stateDir/projects" ]; then
    add_problem "missing on the Mac: $stateDir/projects/"
  fi

  count_result H-07 "the login files are not in the state folder" \
    ".claude.json, .credentials.json and projects/ are in $stateDir"
}

# ------------------------------------------------------------------------------
# Checks claude auth status says logged in
# ------------------------------------------------------------------------------
check_auth_status() {
  add_login_problem
  count_result H-07 "claude auth status does not show a login" \
    'claude auth status shows "loggedIn": true'
}

# ------------------------------------------------------------------------------
# Checks no .claude.json sits in the container home
# ------------------------------------------------------------------------------
check_no_home_json() {
  local homeCount

  homeCount=$(in_container sh -c 'ls -a "$HOME" | grep -c "^\.claude\.json$"')

  if [ "$homeCount" != "0" ]; then
    add_problem "count of .claude.json in the home listing: $homeCount"
  fi

  count_result H-07 "a ~/.claude.json sits in the container home" \
    "no ~/.claude.json in the container home"
}

# ------------------------------------------------------------------------------
# Main / Entry Point
# ------------------------------------------------------------------------------
require_no_arguments "$@" || exit 2
require_test_sandbox H-07 || exit 1
run_login
check_login_files
check_auth_status
check_no_home_json
exit_with_result
