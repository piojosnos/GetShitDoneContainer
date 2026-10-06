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
compose_cmd() {
  if [ -z "${RUN:-}" ]; then
    printf 'No run folder, so no compose command is run.\n' >&2
    return 1
  fi

  SBX_NAME=hosttest SBX_DIR="$RUN" docker compose -f "$REPO_DIR/compose.yml" "$@" </dev/null
}

# --------------------------------------------------------------------------------
# run_timeout SECONDS CMD...: runs CMD; kills it after SECONDS; returns 143 on timeout.
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
    kill "$commandPid" 2>/dev/null
  ) >/dev/null 2>&1 &
  watcherPid=$!
  wait "$commandPid"
  exitCode=$?
  kill "$watcherPid" 2>/dev/null
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
    tail -n 20 "$logFile" | sed 's/^/    /'
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
# assert_test_sandbox: true only if sbx-hosttest exists, is labelled sbx.name=hosttest and mounts a sbx-hosttest-* folder.
# --------------------------------------------------------------------------------
assert_test_sandbox() {
  local label mountSource

  label=$(docker container inspect --format '{{index .Config.Labels "sbx.name"}}' "$CONTAINER" 2>/dev/null </dev/null) || return 1
  if [ "$label" != "hosttest" ]; then
    return 1
  fi

  mountSource=$(docker container inspect \
    --format '{{range .Mounts}}{{if eq .Destination "/home/sandbox/workspace"}}{{.Source}}{{end}}{{end}}' \
    "$CONTAINER" 2>/dev/null </dev/null) || return 1
  case "$mountSource" in
    *sbx-hosttest-*) return 0 ;;
  esac

  return 1
}

# --------------------------------------------------------------------------------
# require_test_sandbox ID: true when the test sandbox is running; else prints a FAIL line for ID, returns 1.
# --------------------------------------------------------------------------------
require_test_sandbox() {
  local checkId=$1
  local running

  if [ -n "${RUN:-}" ]; then
    running=$(docker container inspect --format '{{.State.Running}}' "$CONTAINER" 2>/dev/null </dev/null)
    if [ "$running" = "true" ] && assert_test_sandbox; then
      return 0
    fi
  fi

  fail "$checkId" "the test sandbox is not running" "run: bash tests/host/run-all.sh first"

  return 1
}
