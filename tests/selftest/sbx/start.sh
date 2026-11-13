#!/usr/bin/env bash
# ------------------------------------------------------------------------------
# Self-test of sbx-start with Docker not answering, and the shared warning text
# ------------------------------------------------------------------------------
# Usage: bash tests/selftest/sbx/start.sh (exit 0 = all pass)
# Run by run-all.sh; its one work folder under TMPDIR is removed at exit.
# Docker points at a missing socket, so no case reaches a daemon.
# ------------------------------------------------------------------------------
set -u
. "$(dirname "$0")/lib.sh"

# ------------------------------------------------------------------------------
# Case: Docker not answering is refused before compose up, with its own message
# ------------------------------------------------------------------------------
case_docker_down() {
  SBX_CONFIG_DIR=$WORK/cfg-start-docker
  export SBX_CONFIG_DIR

  echo '--- sbx-start with Docker stopped'

  run_sbx downadd sbx-add down "$WORK/start dir/down"

  run_sbx downstart sbx-start down
  expect "sbx-start: Docker not answering is refused before compose up" refused_cleanly downstart "cannot reach Docker; is Docker running?" "" ""
  expect "sbx-start: Docker not answering does not advise sbx-upgrade" lacks_text "$WORK/downstart.err" "sbx-upgrade"
}

# ------------------------------------------------------------------------------
# Case: sbx-upgrade and sbx-start share one warning wording
# ------------------------------------------------------------------------------
case_shared_wording() {
  local upgradeLine

  echo '--- the shared warning'

  upgradeLine=$(lib_eval 'scriptName=sbx-upgrade; warn_sessions_close demo "is running; after the build, recreating it"' 2>&1)
  expect "sbx-upgrade: the warning keeps its wording" equals "$upgradeLine" "sbx-upgrade: sbx-demo is running; after the build, recreating it will close its open shells and Claude sessions"
}

# ------------------------------------------------------------------------------
# Main / Entry Point
# ------------------------------------------------------------------------------
require_no_arguments "$@" || exit 2
start_group || exit 1
case_docker_down
case_shared_wording
finish_cases
