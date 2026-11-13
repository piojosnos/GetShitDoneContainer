#!/usr/bin/env bash
# ------------------------------------------------------------------------------
# Self-test of sbx-shell: refusals before Docker, and Docker not answering
# ------------------------------------------------------------------------------
# Usage: bash tests/selftest/sbx/shell.sh (exit 0 = all pass)
# Run by run-all.sh; its one work folder under TMPDIR is removed at exit.
# Docker points at a missing socket, so no case reaches a daemon.
# ------------------------------------------------------------------------------
set -u
. "$(dirname "$0")/lib.sh"

# ------------------------------------------------------------------------------
# Case: bad input is refused before any docker call
# ------------------------------------------------------------------------------
case_shell_refusals() {
  local ruleText='breaks the sandbox name rule'

  SBX_CONFIG_DIR=$WORK/cfg-shell-refusals
  export SBX_CONFIG_DIR

  echo '--- sbx-shell refusals'

  run_sbx shell1 sbx-shell
  expect "sbx-shell: no argument prints the usage and exits 2" usage_printed shell1 "Usage: sbx-shell NAME"

  run_sbx shell2 sbx-shell one two
  expect "sbx-shell: two arguments print the usage and exit 2" usage_printed shell2 "Usage: sbx-shell NAME"

  run_sbx shell3 sbx-shell nosuch
  expect "sbx-shell: an unregistered name is refused" refused_cleanly shell3 "is not registered; run: sbx-add" "" ""

  run_sbx shell4 sbx-shell ../x
  expect "sbx-shell: a path as a name is refused" refused_cleanly shell4 "$ruleText" "" ""

  run_sbx shell5 sbx-shell Demo
  expect "sbx-shell: an uppercase name is refused" refused_cleanly shell5 "$ruleText" "" ""
}

# ------------------------------------------------------------------------------
# Case: a wrong folder or Docker not answering is refused before compose
# ------------------------------------------------------------------------------
case_shell_checks_before_compose() {
  local folderRoot="$WORK/shell dir/checks"

  SBX_CONFIG_DIR=$WORK/cfg-shell-checks
  export SBX_CONFIG_DIR

  echo '--- sbx-shell checks before compose'

  run_sbx nofolder sbx-add nofolder "$folderRoot/one"
  mv "$folderRoot/one/nofolder" "$folderRoot/one/nofolder-aside"
  run_sbx nofolderrun sbx-shell nofolder
  expect "sbx-shell: a missing project folder is refused before compose and the shell" refused_cleanly nofolderrun "missing $folderRoot/one/nofolder" "" ""

  run_sbx nostate sbx-add nostate "$folderRoot/two"
  mv "$folderRoot/two/state" "$folderRoot/two/state-aside"
  run_sbx nostaterun sbx-shell nostate
  expect "sbx-shell: a missing state folder is refused before compose and the shell" refused_cleanly nostaterun "missing $folderRoot/two/state" "" ""

  run_sbx noimage sbx-add noimage "$folderRoot/three"
  run_sbx dockerdownrun sbx-shell noimage
  expect "sbx-shell: Docker not answering is refused before compose and the shell" refused_cleanly dockerdownrun "cannot reach Docker; is Docker running?" "" ""
  expect "sbx-shell: Docker not answering does not advise sbx-upgrade" lacks_text "$WORK/dockerdownrun.err" "sbx-upgrade"
}

# ------------------------------------------------------------------------------
# Main / Entry Point
# ------------------------------------------------------------------------------
require_no_arguments "$@" || exit 2
start_group || exit 1
case_shell_refusals
case_shell_checks_before_compose
finish_cases
