#!/usr/bin/env bash
# H-07 (attended): log in to Claude inside the test sandbox, then check where the login landed.
# - Needs a terminal. Run it after bash tests/host/run-all.sh, against the same test sandbox
#   (sbx-hosttest). It finds the run folder from the container's mount; there is no pointer file.
# - You log in with a claude.ai account, then type /exit. Three lines follow, PASS or FAIL each:
#   the login files are on the Mac, claude auth status says logged in, no ~/.claude.json at home.
# - Usage: bash tests/host/manual/h07-login.sh   (exit 0 = every line is PASS)
set -u

. "$(dirname "$0")/lib-manual.sh"
require_terminal

. "$(dirname "$0")/../lib.sh"
host_init

stateDir="$RUN/state/claude"

# --------------------------------------------------------------------------------
# Opens Claude in the test sandbox for the login
# --------------------------------------------------------------------------------
run_login() {
  printf 'Claude opens next, inside the test sandbox.\n'
  printf '  1. Log in with a claude.ai account.\n'
  printf '  2. Type /exit to come back here.\n\n'
  run_claude
  printf '\n'
}

# --------------------------------------------------------------------------------
# Checks the login files reached the state folder on the Mac
# --------------------------------------------------------------------------------
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

# --------------------------------------------------------------------------------
# Checks claude auth status says logged in
# --------------------------------------------------------------------------------
check_auth_status() {
  add_login_problem
  count_result H-07 "claude auth status does not show a login" \
    'claude auth status shows "loggedIn": true'
}

# --------------------------------------------------------------------------------
# Checks no .claude.json sits in the container home
# --------------------------------------------------------------------------------
check_no_home_json() {
  local homeCount

  homeCount=$(in_container sh -c 'ls -a "$HOME" | grep -c "^\.claude\.json$"')

  if [ "$homeCount" != "0" ]; then
    add_problem "count of .claude.json in the home listing: $homeCount"
  fi

  count_result H-07 "a ~/.claude.json sits in the container home" \
    "no ~/.claude.json in the container home"
}

# --------------------------------------------------------------------------------
# Main / Entry Point
# --------------------------------------------------------------------------------
require_no_arguments "$@" || exit 2
require_test_sandbox H-07 || exit 1
run_login
check_login_files
check_auth_status
check_no_home_json
exit_with_result
