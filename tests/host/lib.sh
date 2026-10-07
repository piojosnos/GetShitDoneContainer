#!/usr/bin/env bash
# Shared setup for the host tests: the run folder and a scrubbed environment; loads the topic libraries.
# - Sourced by run-all.sh, by every check, by the self-tests in tests/selftest/ (through lib-expect.sh) and by the guard in tests/guard/ (through lib.sh); never run directly.
# - Loads lib-report.sh (PASS and FAIL lines, collecting a check's result), lib-sandbox.sh (the test
#   sandbox) and lib-docker.sh (the images and the old containers), all from this folder.
# - Sets no shell options and does not cd, so the caller keeps control of both.
# - The caller's SBX_NAME, SBX_DIR and COMPOSE_* values are never used.
# - Deletes nothing.
# - Host side code is stock bash 3.2 with BSD tools (macOS); GNU tools only inside docker exec.

# The topic libraries live next to this file.
. "$(dirname "${BASH_SOURCE[0]}")/lib-report.sh"
. "$(dirname "${BASH_SOURCE[0]}")/lib-sandbox.sh"
. "$(dirname "${BASH_SOURCE[0]}")/lib-docker.sh"

# --------------------------------------------------------------------------------
# host_init: sets REPO_DIR, HOST_DIR, SBX_NAME, CONTAINER and RUN; scrubs the environment.
# --------------------------------------------------------------------------------
host_init() {
  local libDir

  libDir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)
  HOST_DIR=$libDir
  REPO_DIR=$(cd "$libDir/../.." && pwd -P)

  unset COMPOSE_PROJECT_NAME COMPOSE_FILE COMPOSE_PROFILES COMPOSE_PATH_SEPARATOR SBX_DIR
  SBX_NAME=hosttest
  export SBX_NAME
  CONTAINER=sbx-hosttest

  resolve_run_dir
}

# --------------------------------------------------------------------------------
# print_usage [OPTIONS]: prints "Usage: bash SCRIPT OPTIONS" to stderr, SCRIPT as it was run.
# --------------------------------------------------------------------------------
print_usage() {
  printf 'Usage: bash %s%s\n' "$0" "${1:+ $1}" >&2
}

# --------------------------------------------------------------------------------
# require_no_arguments ARG...: for a script that takes no arguments; prints the usage and returns 1 when any is given.
# --------------------------------------------------------------------------------
# The caller stops with || exit 2, the exit code of a usage error.
require_no_arguments() {
  if [ "$#" -gt 0 ]; then
    print_usage
    return 1
  fi

  return 0
}

# --------------------------------------------------------------------------------
# run_dir_name_ok PATH: true if the last path component starts with sbx-hosttest-.
# --------------------------------------------------------------------------------
run_dir_name_ok() {
  local folderName

  folderName=$(basename "$1")
  case "$folderName" in
    sbx-hosttest-*) return 0 ;;
  esac

  return 1
}

# --------------------------------------------------------------------------------
# resolve_run_dir: sets RUN from SBXTEST_DIR, else from the test container's mount; else empty.
# --------------------------------------------------------------------------------
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

# --------------------------------------------------------------------------------
# make_run_dir: creates a fresh run folder (hosttest, state, logs inside); sets RUN, exports SBXTEST_DIR.
# --------------------------------------------------------------------------------
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
