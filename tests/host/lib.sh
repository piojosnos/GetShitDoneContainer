#!/usr/bin/env bash
# ------------------------------------------------------------------------------
# Shared setup for the host tests: run folder, clean environment, libraries
# ------------------------------------------------------------------------------
# Sourced by the checks, runner, guard and self-tests; never run directly.
# Host code is stock bash 3.2 with BSD tools (macOS); GNU only in docker exec.
# ------------------------------------------------------------------------------

. "$(dirname "${BASH_SOURCE[0]}")/lib-report.sh"
. "$(dirname "${BASH_SOURCE[0]}")/lib-sandbox.sh"
. "$(dirname "${BASH_SOURCE[0]}")/lib-docker.sh"

# ------------------------------------------------------------------------------
# host_init: sets REPO_DIR, HOST_DIR, SBX_NAME, PROJECT_DIR, CONTAINER, RUN
# ------------------------------------------------------------------------------
# SBX_DIR and COMPOSE_* are unset, so a caller's values never reach the test.
# ------------------------------------------------------------------------------
host_init() {
  local libDir

  libDir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)
  HOST_DIR=$libDir
  REPO_DIR=$(cd "$libDir/../.." && pwd -P)

  unset COMPOSE_PROJECT_NAME COMPOSE_FILE COMPOSE_PROFILES COMPOSE_PATH_SEPARATOR COMPOSE_ENV_FILES COMPOSE_IGNORE_ORPHANS COMPOSE_REMOVE_ORPHANS SBX_DIR
  SBX_NAME=hosttest
  export SBX_NAME
  PROJECT_DIR=/home/sandbox/workspace/$SBX_NAME
  CONTAINER=sbx-hosttest

  resolve_run_dir
}

# ------------------------------------------------------------------------------
# print_usage [OPTIONS]: prints the usage line to stderr
# ------------------------------------------------------------------------------
print_usage() {
  printf 'Usage: bash %s%s\n' "$0" "${1:+ $1}" >&2
}

# ------------------------------------------------------------------------------
# require_no_arguments ARG...: prints the usage and returns 1 given any ARG
# ------------------------------------------------------------------------------
# The caller stops with || exit 2, the exit code of a usage error.
# ------------------------------------------------------------------------------
require_no_arguments() {
  if [ "$#" -gt 0 ]; then
    print_usage ""
    return 1
  fi

  return 0
}

# ------------------------------------------------------------------------------
# run_dir_name_ok PATH: true if PATH's last component starts with sbx-hosttest-
# ------------------------------------------------------------------------------
run_dir_name_ok() {
  local folderName

  folderName=$(basename "$1")
  case "$folderName" in
    sbx-hosttest-*) return 0 ;;
  esac

  return 1
}

# ------------------------------------------------------------------------------
# resolve_run_dir: sets RUN from SBXTEST_DIR or the container's mount
# ------------------------------------------------------------------------------
resolve_run_dir() {
  local mountSource

  RUN=""

  if [ -n "${SBXTEST_DIR:-}" ]; then
    if [ -d "$SBXTEST_DIR" ] && run_dir_name_ok "$SBXTEST_DIR"; then
      RUN=$(cd "$SBXTEST_DIR" && pwd -P)
    else
      printf 'SBXTEST_DIR is not an existing folder named sbx-hosttest-*: %s\n' "$SBXTEST_DIR" >&2
    fi

    return 0
  fi

  mountSource=$(sandbox_mount_source) || return 0

  if [ -z "$mountSource" ]; then
    return 0
  fi

  if [ -d "$mountSource" ] && run_dir_name_ok "$mountSource"; then
    RUN=$(cd "$mountSource" && pwd -P)
  else
    printf 'The %s mount is not a folder visible on this machine: %s\n' "$CONTAINER" "$mountSource" >&2
  fi

  return 0
}

# ------------------------------------------------------------------------------
# make_run_dir: creates a fresh run folder; sets RUN, exports SBXTEST_DIR
# ------------------------------------------------------------------------------
make_run_dir() {
  local baseDir created

  baseDir=${TMPDIR:-/tmp}
  baseDir=${baseDir%/}

  if [ -z "$baseDir" ]; then
    baseDir=/tmp
  fi

  if ! created=$(mktemp -d "$baseDir/sbx-hosttest-$(date +%Y%m%d-%H%M%S).XXXXXX"); then
    printf 'Could not create a run folder under %s\n' "$baseDir" >&2
    return 1
  fi

  RUN=$(cd "$created" && pwd -P) || return 1
  mkdir -p "$RUN/hosttest" "$RUN/state" "$RUN/logs" || return 1
  SBXTEST_DIR=$RUN
  export SBXTEST_DIR

  return 0
}
