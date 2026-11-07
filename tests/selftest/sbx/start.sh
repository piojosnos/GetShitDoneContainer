#!/usr/bin/env bash
# ------------------------------------------------------------------------------
# Self-test of sbx-start past the folder checks, against a scripted docker
# ------------------------------------------------------------------------------
# Usage: bash tests/selftest/sbx/start.sh (exit 0 = all pass)
# Run by run-all.sh; its one work folder under TMPDIR is removed at exit.
# The refusing stand-in stays first on PATH except inside run_sbx_scripted.
# ------------------------------------------------------------------------------
set -u
. "$(dirname "$0")/lib.sh"

# ------------------------------------------------------------------------------
# Case: a container that is gone during the start wait is reported, not silent
# ------------------------------------------------------------------------------
case_container_gone() {
  SBX_CONFIG_DIR=$WORK/cfg-start
  export SBX_CONFIG_DIR

  echo '--- sbx-start when the container disappears'

  run_sbx gone sbx-add gone "$WORK/start dir/gone"
  set_standin_state sha256:new "" "" no
  run_sbx_scripted gonestart sbx-start gone
  expect "sbx-start: a container that is gone is reported as stopped during its start" refused_cleanly gonestart "sbx-gone stopped during its start" "" ""
  expect "sbx-start: the compose up ran before the wait" has_text "$WORK/gonestart.out" "standin: compose"
}

# ------------------------------------------------------------------------------
# Main / Entry Point
# ------------------------------------------------------------------------------
require_no_arguments "$@" || exit 2
start_group || exit 1
make_scripted_docker
case_container_gone
expect "sbx-start: no case reached the refusing docker" no_docker_call
finish_cases
