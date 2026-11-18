#!/usr/bin/env bash
# ------------------------------------------------------------------------------
# Self-test of the refusals of sbx-upgrade: all of them come before the build
# ------------------------------------------------------------------------------
# Usage: bash tests/selftest/sbx/upgrade.sh (exit 0 = all pass)
# Run by run-all.sh; its one work directory under TMPDIR is removed at exit.
# The build is the long step, so every cheap check has to stop the run first.
# ------------------------------------------------------------------------------
set -u
. "$(dirname "$0")/lib.sh"

# ------------------------------------------------------------------------------
# refused_before_build LABEL TEXT: exit 1, TEXT in the error, no build started
# ------------------------------------------------------------------------------
refused_before_build() {
  refused_cleanly "$1" "$2" "" "" || return 1
  lacks_text "$WORK/$1.out" "build.sh: building" || return 1
  lacks_text "$WORK/$1.err" "build.sh: building"
}

# ------------------------------------------------------------------------------
# Case: bad input is refused before build.sh prints anything
# ------------------------------------------------------------------------------
case_upgrade_refusals() {
  local ruleText='breaks the sandbox name rule'
  local dirRoot="$WORK/upgrade dir"

  SBX_CONFIG_DIR=$WORK/cfg-upgrade
  export SBX_CONFIG_DIR

  echo '--- sbx-upgrade refusals'

  run_sbx up1 sbx-upgrade
  expect "sbx-upgrade: no argument prints the usage and exits 2" usage_printed up1 "Usage: sbx-upgrade NAME [BUILD_OPTION...]"

  run_sbx up2 sbx-upgrade nosuch
  expect "sbx-upgrade: an unregistered name is refused before the build" refused_before_build up2 "is not registered; run: sbx-add"

  run_sbx up3 sbx-upgrade ../x
  expect "sbx-upgrade: a path as a name is refused before the build" refused_before_build up3 "$ruleText"

  run_sbx nodir sbx-add nodir "$dirRoot/one"
  mv "$dirRoot/one/nodir" "$dirRoot/one/nodir-aside"
  run_sbx up4 sbx-upgrade nodir --no-cache
  expect "sbx-upgrade: a missing project directory is refused before the build" refused_before_build up4 "missing $dirRoot/one/nodir; create it"

  run_sbx nostate sbx-add nostate "$dirRoot/two"
  mv "$dirRoot/two/state" "$dirRoot/two/state-aside"
  run_sbx up5 sbx-upgrade nostate
  expect "sbx-upgrade: a missing state directory is refused before the build" refused_before_build up5 "missing $dirRoot/two/state; create it"
}

# ------------------------------------------------------------------------------
# Main / Entry Point
# ------------------------------------------------------------------------------
require_no_arguments "$@" || exit 2
start_group || exit 1
case_upgrade_refusals
finish_cases
