#!/usr/bin/env bash
# ------------------------------------------------------------------------------
# H-13: the env reaches docker exec; Claude Code self-update is off
# ------------------------------------------------------------------------------
# Needs: test sandbox running
# The claude doctor part needs a terminal: manual/h13-doctor.sh.
# ------------------------------------------------------------------------------
set -u
. "$(dirname "$0")/lib.sh"
host_init

# ------------------------------------------------------------------------------
# Reads the environment, the claude update reply and two path tests
# ------------------------------------------------------------------------------
read_environment() {
  envOutput=$(in_container env)
  updateOutput=$(run_timeout 60 in_container claude update)
  in_container sh -c 'test ! -e "$HOME/.local/share/claude"' >/dev/null
  shareStatus=$?
  in_container sh -c 'test ! -e "$HOME/.local/bin/claude"' >/dev/null
  localBinStatus=$?
}

# ------------------------------------------------------------------------------
# Checks the five variables are visible to docker exec
# ------------------------------------------------------------------------------
check_variables_set() {
  local envName

  for envName in CLAUDE_CONFIG_DIR DISABLE_UPDATES HISTFILE GH_CONFIG_DIR GIT_CONFIG_GLOBAL; do
    if ! printf '%s\n' "$envOutput" | grep -q "^$envName="; then
      add_problem "$envName is not set in docker exec"
    fi
  done
}

# ------------------------------------------------------------------------------
# Checks claude update says updates are disabled
# ------------------------------------------------------------------------------
check_updates_disabled() {
  if [[ "$updateOutput" != *"Updates are disabled by your administrator"* ]]; then
    add_problem "claude update did not say updates are disabled; got: $(first_lines "$updateOutput")"
  fi
}

# ------------------------------------------------------------------------------
# Checks ~/.local/share/claude does not exist in the container home
# ------------------------------------------------------------------------------
# The test exits 0 when the folder is absent and 1 when it exists; any other
# status means docker exec could not check.
# ------------------------------------------------------------------------------
check_no_share_folder() {
  case "$shareStatus" in
    0) ;;
    1) add_problem "~/.local/share/claude exists in the container home" ;;
    *) add_problem "could not check ~/.local/share/claude (docker exec exit $shareStatus)" ;;
  esac
}

# ------------------------------------------------------------------------------
# Checks ~/.local/bin/claude does not exist in the container home
# ------------------------------------------------------------------------------
# The test exits 0 when the file is absent and 1 when it exists; any other
# status means docker exec could not check.
# ------------------------------------------------------------------------------
check_no_local_bin_copy() {
  case "$localBinStatus" in
    0) ;;
    1) add_problem "~/.local/bin/claude exists in the container home: a self-installed Claude copy" ;;
    *) add_problem "could not check ~/.local/bin/claude (docker exec exit $localBinStatus)" ;;
  esac
}

# ------------------------------------------------------------------------------
# Main / Entry Point
# ------------------------------------------------------------------------------
require_no_arguments "$@" || exit 2
require_test_sandbox H-13 || exit 1
read_environment
check_variables_set
check_updates_disabled
check_no_share_folder
check_no_local_bin_copy
report_check H-13 "the environment or the no-self-update setup is wrong" \
  "five variables are set, claude update is disabled, no ~/.local/share/claude, no ~/.local/bin/claude"
