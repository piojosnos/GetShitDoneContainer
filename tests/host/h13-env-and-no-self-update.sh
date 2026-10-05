#!/usr/bin/env bash
# H-13: the environment is visible to docker exec, and Claude Code self-update is off.
# The claude doctor part needs a terminal: it is the manual helper (manual/h13-doctor.sh).
# Depends on: nothing
# Needs: test sandbox running
set -u
. "$(dirname "$0")/lib.sh"
host_init
require_test_sandbox H-13 || exit 1

# --------------------------------------------------------------------------------
# Reads the container environment, the claude update reply and whether ~/.local/share/claude exists
# --------------------------------------------------------------------------------
read_environment() {
  envOutput=$(in_container env)
  updateOutput=$(run_timeout 60 in_container claude update)
  in_container sh -c 'test ! -e "$HOME/.local/share/claude"' >/dev/null
  shareStatus=$?
}

# --------------------------------------------------------------------------------
# Checks the five variables are visible to docker exec
# --------------------------------------------------------------------------------
check_variables_set() {
  local envName

  for envName in CLAUDE_CONFIG_DIR DISABLE_UPDATES HISTFILE GH_CONFIG_DIR GIT_CONFIG_GLOBAL; do
    if ! printf '%s\n' "$envOutput" | grep -q "^$envName="; then
      add_problem "$envName is not set in docker exec"
    fi
  done
}

# --------------------------------------------------------------------------------
# Checks claude update says updates are disabled
# --------------------------------------------------------------------------------
check_updates_disabled() {
  if [[ "$updateOutput" != *"Updates are disabled by your administrator"* ]]; then
    add_problem "claude update did not say updates are disabled; got: $(first_lines "$updateOutput")"
  fi
}

# --------------------------------------------------------------------------------
# Checks ~/.local/share/claude does not exist in the container home
# --------------------------------------------------------------------------------
check_no_share_folder() {
  if [ "$shareStatus" -ne 0 ]; then
    add_problem "~/.local/share/claude exists in the container home"
  fi
}

# --------------------------------------------------------------------------------
# Main / Entry Point
# --------------------------------------------------------------------------------
read_environment
check_variables_set
check_updates_disabled
check_no_share_folder
report_check H-13 "the environment or the no-self-update setup is wrong" \
  "five variables are set, claude update is disabled, no ~/.local/share/claude"
