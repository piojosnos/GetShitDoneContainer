#!/usr/bin/env bash
# ------------------------------------------------------------------------------
# Self-test of sbx-list: the usage line and a Docker failure
# ------------------------------------------------------------------------------
# Usage: bash tests/selftest/sbx/list.sh (exit 0 = all pass)
# Run by run-all.sh; its one work folder under TMPDIR is removed at exit.
# Docker points at a missing socket, so no case reaches a daemon.
# ------------------------------------------------------------------------------
set -u
. "$(dirname "$0")/lib.sh"

# ------------------------------------------------------------------------------
# usage_is_exact LABEL: exit 2 and the error is exactly the usage line
# ------------------------------------------------------------------------------
usage_is_exact() {
  usage_printed "$1" "Usage: sbx-list" && [ "$(cat "$WORK/$1.err")" = "Usage: sbx-list" ]
}

# ------------------------------------------------------------------------------
# failed_without_table LABEL: exit 1, the Docker error, nothing on stdout
# ------------------------------------------------------------------------------
failed_without_table() {
  refused_cleanly "$1" "cannot read the containers from Docker" "" "" && [ ! -s "$WORK/$1.out" ]
}

# ------------------------------------------------------------------------------
# Case: an argument is refused with the usage line
# ------------------------------------------------------------------------------
case_list_usage() {
  SBX_CONFIG_DIR=$WORK/cfg-list-usage
  export SBX_CONFIG_DIR

  echo '--- sbx-list usage'

  run_sbx listusage sbx-list extra
  expect "sbx-list: an argument prints the usage and exits 2" usage_is_exact listusage
}

# ------------------------------------------------------------------------------
# Case: a failed docker ps is an error, never an empty list
# ------------------------------------------------------------------------------
case_list_docker_failure() {
  SBX_CONFIG_DIR=$WORK/cfg-list-failure
  export SBX_CONFIG_DIR

  echo '--- sbx-list docker failure'

  run_sbx failadd sbx-add one "$WORK/list dir/one"

  run_sbx failrun sbx-list
  expect "sbx-list: a failed docker ps exits 1 and prints no table" failed_without_table failrun
}

# ------------------------------------------------------------------------------
# Main / Entry Point
# ------------------------------------------------------------------------------
require_no_arguments "$@" || exit 2
start_group || exit 1
case_list_usage
case_list_docker_failure
finish_cases
