#!/usr/bin/env bash
# ------------------------------------------------------------------------------
# H-06: git works in the container on a repository made on the Mac
# ------------------------------------------------------------------------------
# Needs: test sandbox running
# The host-side git call ignores your own git configuration.
# ------------------------------------------------------------------------------
set -u
. "$(dirname "$0")/lib.sh"
host_init

# ------------------------------------------------------------------------------
# Makes the project folder a git repository from the host
# ------------------------------------------------------------------------------
# GIT_CONFIG_GLOBAL=/dev/null and GIT_CONFIG_NOSYSTEM=1 keep your own identity
# from being read or written.
# ------------------------------------------------------------------------------
init_host_repo() {
  GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_NOSYSTEM=1 git init -q "$RUN/hosttest"
  initStatus=$?

  if [ "$initStatus" -ne 0 ]; then
    add_problem "git init of $RUN/hosttest on the host failed"
  fi
}

# ------------------------------------------------------------------------------
# Runs git status in the container, in the project folder
# ------------------------------------------------------------------------------
read_git_state() {
  statusOutput=$(in_project git status)
  statusCode=$?
}

# ------------------------------------------------------------------------------
# Checks git status ran in the container without an ownership error
# ------------------------------------------------------------------------------
check_git_status() {
  if [ "$statusCode" -ne 0 ] || [[ "$statusOutput" == *"dubious ownership"* ]]; then
    add_problem "git status in the container exited $statusCode: $(first_lines "$statusOutput" 2)"
  fi
}

# ------------------------------------------------------------------------------
# Main / Entry Point
# ------------------------------------------------------------------------------
require_no_arguments "$@" || exit 2
require_test_sandbox H-06 || exit 1
init_host_repo
read_git_state
check_git_status
report_check H-06 "git in the container fails on a repository made on the Mac" \
  "git status works in the container on a repository made on the Mac, with no ownership error"
