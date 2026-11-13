#!/usr/bin/env bash
# ------------------------------------------------------------------------------
# H-13: the env reaches docker exec; no Claude copy sits in the home
# ------------------------------------------------------------------------------
# Needs: test sandbox running
# ------------------------------------------------------------------------------
set -u
. "$(dirname "$0")/lib.sh"
host_init

# ------------------------------------------------------------------------------
# Reads the environment and two path tests
# ------------------------------------------------------------------------------
read_environment() {
  envOutput=$(in_container env)
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

  if ! printf '%s\n' "$envOutput" | grep -qx 'DISABLE_UPDATES=1'; then
    add_problem "DISABLE_UPDATES is not 1 in docker exec"
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
check_no_share_folder
check_no_local_bin_copy
report_check H-13 "the environment or the home setup is wrong" \
  "five variables are set, no ~/.local/share/claude, no ~/.local/bin/claude"
