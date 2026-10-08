#!/usr/bin/env bash
# H-13: the environment is visible to docker exec, and Claude Code self-update is off.
# The claude doctor part needs a terminal: it is the manual helper (manual/h13-doctor.sh).
# Depends on: nothing
# Needs: test sandbox running
set -u
. "$(dirname "$0")/lib.sh"
host_init

# --------------------------------------------------------------------------------
# Reads the container environment, the claude update reply and the exit status of the ~/.local/share/claude test
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
# The test exits 0 when the folder is absent and 1 when it exists; any other status means docker exec could not check.
check_no_share_folder() {
  case "$shareStatus" in
    0) ;;
    1) add_problem "~/.local/share/claude exists in the container home" ;;
    *) add_problem "could not check ~/.local/share/claude (docker exec exit $shareStatus)" ;;
  esac
}

# --------------------------------------------------------------------------------
# Main / Entry Point
# --------------------------------------------------------------------------------
require_no_arguments "$@" || exit 2
require_test_sandbox H-13 || exit 1
read_environment
check_variables_set
check_updates_disabled
check_no_share_folder
report_check H-13 "the environment or the no-self-update setup is wrong" \
  "five variables are set, claude update is disabled, no ~/.local/share/claude"
