#!/usr/bin/env bash
# ------------------------------------------------------------------------------
# H-23: the npm, uv and Maven caches live in state/ and survive a recreate
# ------------------------------------------------------------------------------
# Needs: test sandbox running; stops and restarts it
# Files written into the caches are left in the run folder for the cleanup.
# ------------------------------------------------------------------------------
set -u
. "$(dirname "$0")/lib.sh"
host_init

marker="h23-$$-$(date +%s)"

# ------------------------------------------------------------------------------
# container_stdout CMD...: runs CMD in the test container; stdout only
# ------------------------------------------------------------------------------
# Stdin is closed and stderr discarded, so no tool notice reaches a compared
# value.
# ------------------------------------------------------------------------------
container_stdout() {
  docker exec "$CONTAINER" "$@" </dev/null 2>/dev/null
}

# ------------------------------------------------------------------------------
# Checks the entrypoint made state/cache/npm, state/cache/uv and state/m2
# ------------------------------------------------------------------------------
check_state_folders() {
  local folderName

  for folderName in cache/npm cache/uv m2; do
    if [ ! -d "$RUN/state/$folderName" ]; then
      add_problem "state/$folderName is not a folder; the entrypoint did not make it"
    fi
  done
}

# ------------------------------------------------------------------------------
# Checks npm, uv and Maven find their caches under state
# ------------------------------------------------------------------------------
# npm and uv find them through image ENV (npm config get cache, uv cache dir);
# ~/.m2 is a link into state/m2.
# ------------------------------------------------------------------------------
check_cache_locations() {
  local npmCache uvCache m2Link

  npmCache=$(container_stdout npm config get cache)

  if [ "$npmCache" != "/home/sandbox/workspace/state/cache/npm" ]; then
    add_problem "npm keeps its cache in '$npmCache', not in /home/sandbox/workspace/state/cache/npm"
  fi

  uvCache=$(container_stdout uv cache dir)

  if [ "$uvCache" != "/home/sandbox/workspace/state/cache/uv" ]; then
    add_problem "uv keeps its cache in '$uvCache', not in /home/sandbox/workspace/state/cache/uv"
  fi

  m2Link=$(container_stdout readlink /home/sandbox/.m2)

  if [ "$m2Link" != "/home/sandbox/workspace/state/m2" ]; then
    add_problem "~/.m2 points to '$m2Link', not to /home/sandbox/workspace/state/m2"
  fi
}

# ------------------------------------------------------------------------------
# Writes the marker into a file in each cache, from inside the container
# ------------------------------------------------------------------------------
plant_cache_files() {
  in_container sh -c ': h23-plant; for cacheDir in "$NPM_CONFIG_CACHE" "$UV_CACHE_DIR" "$HOME/.m2"; do printf "%s\n" "$1" >"$cacheDir/$1"; done' h23-plant "$marker" >/dev/null
}

# ------------------------------------------------------------------------------
# check_files_on_host WHEN: each cache folder on the Mac holds the marker
# ------------------------------------------------------------------------------
# WHEN names the moment in the message.
# ------------------------------------------------------------------------------
check_files_on_host() {
  local folderName

  for folderName in cache/npm cache/uv m2; do
    if ! grep -Fq "$marker" "$RUN/state/$folderName/$marker" 2>/dev/null; then
      add_problem "state/$folderName/$marker is missing on the Mac $1"
    fi
  done
}

# ------------------------------------------------------------------------------
# Main / Entry Point
# ------------------------------------------------------------------------------
require_no_arguments "$@" || exit 2
require_test_sandbox H-23 || exit 1
check_state_folders
check_cache_locations
plant_cache_files
check_files_on_host "before the recreate"
restart_test_sandbox H-23 h23-down.log || exit 1
check_files_on_host "after the recreate"
report_check H-23 "a cache is not in the state folder or did not survive the recreate" \
  "npm, uv and Maven use state/cache/npm, state/cache/uv and state/m2, and a file in each survived the recreate"
