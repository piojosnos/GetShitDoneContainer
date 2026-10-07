#!/usr/bin/env bash
# The test sandbox for the host tests: run commands in it, start and stop it, and refuse to act on anything else.
# - Loaded by lib.sh; never run directly. Defines functions only.
# - Every Docker call is aimed at the throwaway sandbox: project hosttest, container sbx-hosttest.
# - Reads CONTAINER, RUN and REPO_DIR, set by host_init. Never removes volumes.
# - Host side code is stock bash 3.2 with BSD tools (macOS).

# --------------------------------------------------------------------------------
# in_container CMD...: runs CMD in the test container; stdin closed, stderr merged, never a tty.
# --------------------------------------------------------------------------------
in_container() {
  docker exec "$CONTAINER" "$@" </dev/null 2>&1
}

# --------------------------------------------------------------------------------
# compose_cmd ARGS...: runs docker compose against compose.yml for the test sandbox only.
# --------------------------------------------------------------------------------
# --env-file /dev/null: a .env file in the repo never reaches the test sandbox.
compose_cmd() {
  if [ -z "${RUN:-}" ]; then
    printf 'No run folder, so no compose command is run.\n' >&2
    return 1
  fi

  SBX_NAME=hosttest SBX_DIR="$RUN" docker compose --env-file /dev/null -f "$REPO_DIR/compose.yml" "$@" </dev/null
}

# --------------------------------------------------------------------------------
# tree_pids PID: prints PID, then every process it started, parent first, one per line.
# --------------------------------------------------------------------------------
tree_pids() {
  local parentPid=$1
  local childPid

  printf '%s\n' "$parentPid"

  for childPid in $(pgrep -P "$parentPid" 2>/dev/null); do
    tree_pids "$childPid"
  done
}

# --------------------------------------------------------------------------------
# kill_tree PID: stops PID and everything it started; collects the list first, then signals all in one call; returns 0.
# --------------------------------------------------------------------------------
kill_tree() {
  local pidList

  pidList=$(tree_pids "$1")

  # The list is left unquoted on purpose: kill takes one argument per pid.
  kill $pidList 2>/dev/null

  return 0
}

# --------------------------------------------------------------------------------
# run_timeout SECONDS CMD...: runs CMD; after SECONDS stops it and everything it started; returns 143 on timeout.
# --------------------------------------------------------------------------------
run_timeout() {
  local seconds=$1
  local commandPid watcherPid exitCode

  shift
  "$@" &
  commandPid=$!
  (
    elapsedSeconds=0

    while [ "$elapsedSeconds" -lt "$seconds" ]; do
      sleep 1

      if ! kill -0 "$commandPid" 2>/dev/null; then
        exit 0
      fi
      elapsedSeconds=$((elapsedSeconds + 1))
    done
    kill_tree "$commandPid"
  ) >/dev/null 2>&1 &
  watcherPid=$!
  wait "$commandPid"
  exitCode=$?
  kill_tree "$watcherPid"
  wait "$watcherPid" 2>/dev/null

  return "$exitCode"
}

# --------------------------------------------------------------------------------
# compose_up: starts the test sandbox and waits; log in the run folder; returns the exit code.
# --------------------------------------------------------------------------------
compose_up() {
  local logFile exitCode

  logFile="$RUN/logs/compose-up.log"
  run_timeout 120 compose_cmd up -d --wait >"$logFile" 2>&1
  exitCode=$?

  if [ "$exitCode" -ne 0 ]; then
    printf 'compose up failed (exit %s); last lines of %s:\n' "$exitCode" "$logFile"
    print_log_tail "$logFile"
    printf 'If the log says the mount was denied, the run folder is not under a folder shared with Docker Desktop (Settings, Resources, File sharing).\n'
  fi

  return "$exitCode"
}

# --------------------------------------------------------------------------------
# compose_down: takes the test sandbox down (never removes volumes); refuses if sbx-hosttest is not the test sandbox.
# --------------------------------------------------------------------------------
compose_down() {
  if docker container inspect "$CONTAINER" >/dev/null 2>&1 </dev/null; then
    if ! assert_test_sandbox; then
      printf 'Refusing compose down: %s is not the test sandbox.\n' "$CONTAINER" >&2
      return 1
    fi
  fi

  compose_cmd down
}

# --------------------------------------------------------------------------------
# restart_test_sandbox ID LOG_NAME: compose down, then up; on a failure prints FAIL for ID and returns 1.
# --------------------------------------------------------------------------------
restart_test_sandbox() {
  local checkId=$1
  local logFile

  logFile="$RUN/logs/$2"

  if ! compose_down >"$logFile" 2>&1; then
    fail "$checkId" "compose down failed" "log: $logFile"
    return 1
  fi

  if ! compose_up; then
    fail "$checkId" "compose up failed after the down" "log: $RUN/logs/compose-up.log"
    return 1
  fi
}

# --------------------------------------------------------------------------------
# sandbox_mount_source: prints the host folder mounted at /home/sandbox/workspace in sbx-hosttest; returns 1 when the container cannot be inspected.
# --------------------------------------------------------------------------------
sandbox_mount_source() {
  docker container inspect \
    --format '{{range .Mounts}}{{if eq .Destination "/home/sandbox/workspace"}}{{.Source}}{{end}}{{end}}' \
    "$CONTAINER" 2>/dev/null </dev/null
}

# --------------------------------------------------------------------------------
# assert_test_sandbox: for cleanup; true only if sbx-hosttest is labelled sbx.name=hosttest and its mount, or the folder holding the mount, is named sbx-hosttest-*.
# --------------------------------------------------------------------------------
# Loose on purpose: it accepts the sandbox of an earlier run and the exited containers
# that H-10 and the mistyped-name check leave on a folder inside a run folder.
assert_test_sandbox() {
  local label mountSource

  label=$(docker container inspect --format '{{index .Config.Labels "sbx.name"}}' "$CONTAINER" 2>/dev/null </dev/null) || return 1

  if [ "$label" != "hosttest" ]; then
    return 1
  fi

  mountSource=$(sandbox_mount_source) || return 1

  if [ -z "$mountSource" ]; then
    return 1
  fi

  if run_dir_name_ok "$mountSource"; then
    return 0
  fi

  if run_dir_name_ok "$(dirname "$mountSource")"; then
    return 0
  fi

  return 1
}

# --------------------------------------------------------------------------------
# assert_this_run_sandbox: for a check about to act; true only if assert_test_sandbox holds and the mount folder has the same name as the run folder.
# --------------------------------------------------------------------------------
assert_this_run_sandbox() {
  local mountSource

  assert_test_sandbox || return 1

  mountSource=$(sandbox_mount_source) || return 1

  [ "$(basename "$mountSource")" = "$(basename "${RUN:-}")" ]
}

# --------------------------------------------------------------------------------
# require_test_sandbox ID: true when the test sandbox of this run is running; else prints a FAIL line for ID, returns 1.
# --------------------------------------------------------------------------------
require_test_sandbox() {
  local checkId=$1
  local running

  if [ -n "${RUN:-}" ]; then
    running=$(docker container inspect --format '{{.State.Running}}' "$CONTAINER" 2>/dev/null </dev/null)

    if [ "$running" = "true" ] && assert_this_run_sandbox; then
      return 0
    fi

    if [ "$running" = "true" ] && assert_test_sandbox; then
      fail "$checkId" "sbx-hosttest mounts another run folder: $(sandbox_mount_source)" \
        "set SBXTEST_DIR to that folder, or run: bash tests/host/run-all.sh"

      return 1
    fi
  fi

  fail "$checkId" "the test sandbox is not running" "run: bash tests/host/run-all.sh first"

  return 1
}
