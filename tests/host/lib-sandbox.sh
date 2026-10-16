#!/usr/bin/env bash
# ------------------------------------------------------------------------------
# The test sandbox for the host tests: run in it, start, stop, refuse others
# ------------------------------------------------------------------------------
# Sourced by tests/host/lib.sh; runs nothing. Reads CONTAINER and RUN.
# Every Docker call targets container sbx-hosttest only; no volume is removed.
# ------------------------------------------------------------------------------

# ------------------------------------------------------------------------------
# in_container CMD...: runs CMD in the test container (no stdin, stderr merged)
# ------------------------------------------------------------------------------
in_container() {
  docker exec "$CONTAINER" "$@" </dev/null 2>&1
}

# ------------------------------------------------------------------------------
# in_project CMD...: like in_container, in the project folder
# ------------------------------------------------------------------------------
in_project() {
  docker exec -w "$PROJECT_DIR" "$CONTAINER" "$@" </dev/null 2>&1
}

# ------------------------------------------------------------------------------
# compose_cmd ARGS...: runs docker compose on compose.yml for the test sandbox
# ------------------------------------------------------------------------------
# --env-file /dev/null: a .env file in the repo never reaches the test sandbox.
compose_cmd() {
  if [ -z "${RUN:-}" ]; then
    printf 'No run folder, so no compose command is run.\n' >&2
    return 1
  fi

  SBX_NAME=hosttest SBX_DIR="$RUN" docker compose --env-file /dev/null -f "$REPO_DIR/compose.yml" "$@" </dev/null
}

# ------------------------------------------------------------------------------
# tree_pids PID: prints PID, then every process it started, parent first
# ------------------------------------------------------------------------------
tree_pids() {
  local parentPid=$1
  local childPid

  printf '%s\n' "$parentPid"

  for childPid in $(pgrep -P "$parentPid" 2>/dev/null); do
    tree_pids "$childPid"
  done
}

# ------------------------------------------------------------------------------
# kill_tree PID: stops PID and everything it started; returns 0
# ------------------------------------------------------------------------------
# The list is collected first, then signalled in one call.
# ------------------------------------------------------------------------------
kill_tree() {
  local pidList

  pidList=$(tree_pids "$1")

  # The list is left unquoted on purpose: kill takes one argument per pid.
  kill $pidList 2>/dev/null

  return 0
}

# ------------------------------------------------------------------------------
# any_alive PID...: true when at least one of the pids still exists
# ------------------------------------------------------------------------------
any_alive() {
  local checkedPid

  for checkedPid in "$@"; do
    if kill -0 "$checkedPid" 2>/dev/null; then
      return 0
    fi
  done

  return 1
}

# ------------------------------------------------------------------------------
# run_timeout SECONDS CMD...: runs CMD; after SECONDS stops it and its children
# ------------------------------------------------------------------------------
# macOS has no timeout command. SIGTERM first, SIGKILL after a 5 s grace.
# Returns 143 on a timeout, or 137 when it had to be killed.
# ------------------------------------------------------------------------------
run_timeout() {
  local seconds=$1
  local graceSeconds=5
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

    # The list is taken first: children are re-parented once their parent dies.
    pidList=$(tree_pids "$commandPid")

    # The list is left unquoted on purpose: kill takes one argument per pid.
    kill $pidList 2>/dev/null
    graceElapsed=0

    while [ "$graceElapsed" -lt "$graceSeconds" ]; do
      sleep 1

      if ! any_alive $pidList; then
        exit 0
      fi
      graceElapsed=$((graceElapsed + 1))
    done
    kill -9 $pidList 2>/dev/null
  ) >/dev/null 2>&1 &
  watcherPid=$!
  wait "$commandPid"
  exitCode=$?

  # After 143 or 137 the watcher may still be in its grace loop; let it end.
  # Any other status stops it at once.
  if [ "$exitCode" -eq 143 ] || [ "$exitCode" -eq 137 ]; then
    wait "$watcherPid" 2>/dev/null
  else
    kill_tree "$watcherPid"
    wait "$watcherPid" 2>/dev/null
  fi

  return "$exitCode"
}

# ------------------------------------------------------------------------------
# wait_for_start_hooks: returns 0 once every start hook has finished, else 1
# ------------------------------------------------------------------------------
# The entrypoint execs sleep after the last hook, so a running sleep means done.
# SBXTEST_START_SECONDS (optional, default 120) sets how long this waits.
# ------------------------------------------------------------------------------
wait_for_start_hooks() {
  local limitSeconds=${SBXTEST_START_SECONDS:-120}
  local waitedSeconds=0
  local running

  case "$limitSeconds" in
    ''|*[!0-9]*) limitSeconds=120 ;;
  esac

  while [ "$waitedSeconds" -lt "$limitSeconds" ]; do
    if docker exec "$CONTAINER" pgrep -x sleep >/dev/null 2>&1 </dev/null; then
      return 0
    fi

    running=$(docker container inspect --format '{{.State.Running}}' "$CONTAINER" 2>/dev/null </dev/null)

    if [ "$running" != "true" ]; then
      printf 'The test sandbox stopped during its start; docker logs %s shows why.\n' "$CONTAINER"

      return 1
    fi

    sleep 1
    waitedSeconds=$((waitedSeconds + 1))
  done

  printf 'The start hooks of the test sandbox did not finish within %s s.\n' "$limitSeconds"

  return 1
}

# ------------------------------------------------------------------------------
# compose_up: starts the test sandbox and waits for its start hooks
# ------------------------------------------------------------------------------
# Log: RUN/logs/compose-up.log. Returns the exit code of the failing step.
# ------------------------------------------------------------------------------
compose_up() {
  local logFile exitCode

  logFile="$RUN/logs/compose-up.log"
  run_timeout 120 compose_cmd up -d --wait >"$logFile" 2>&1
  exitCode=$?

  if [ "$exitCode" -ne 0 ]; then
    printf 'compose up failed (exit %s); last lines of %s:\n' "$exitCode" "$logFile"
    print_log_tail "$logFile"
    printf 'If the log says the mount was denied, the run folder is not under a folder shared with Docker Desktop (Settings, Resources, File sharing).\n'

    return "$exitCode"
  fi

  if ! wait_for_start_hooks >>"$logFile" 2>&1; then
    printf 'the start hooks did not finish; last lines of %s:\n' "$logFile"
    print_log_tail "$logFile"

    return 1
  fi

  return 0
}

# ------------------------------------------------------------------------------
# compose_down: takes the test sandbox down, never its volumes
# ------------------------------------------------------------------------------
# Refuses if sbx-hosttest is not the test sandbox.
# ------------------------------------------------------------------------------
compose_down() {
  if docker container inspect "$CONTAINER" >/dev/null 2>&1 </dev/null; then
    if ! assert_test_sandbox; then
      printf 'Refusing compose down: %s is not the test sandbox.\n' "$CONTAINER" >&2
      return 1
    fi
  fi

  compose_cmd down
}

# ------------------------------------------------------------------------------
# restart_test_sandbox ID LOG_NAME: compose down, then up; FAIL for ID, 1 if not
# ------------------------------------------------------------------------------
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

# ------------------------------------------------------------------------------
# sandbox_mount_source: prints the host folder mounted at the workspace
# ------------------------------------------------------------------------------
# Returns 1 when sbx-hosttest cannot be inspected.
# ------------------------------------------------------------------------------
sandbox_mount_source() {
  docker container inspect \
    --format '{{range .Mounts}}{{if eq .Destination "/home/sandbox/workspace"}}{{.Source}}{{end}}{{end}}' \
    "$CONTAINER" 2>/dev/null </dev/null
}

# ------------------------------------------------------------------------------
# assert_test_sandbox: for cleanup; true only for the labelled test sandbox
# ------------------------------------------------------------------------------
# Needs label sbx.name=hosttest; the mount or its parent is sbx-hosttest-*.
# Loose: also accepts an earlier run's sandbox and what H-10 and H-20 leave.
# ------------------------------------------------------------------------------
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

# ------------------------------------------------------------------------------
# assert_this_run_sandbox: true only for the test sandbox of this run
# ------------------------------------------------------------------------------
# For a check about to act: the mount folder must be named like the run folder.
# ------------------------------------------------------------------------------
assert_this_run_sandbox() {
  local mountSource

  assert_test_sandbox || return 1

  mountSource=$(sandbox_mount_source) || return 1

  [ "$(basename "$mountSource")" = "$(basename "${RUN:-}")" ]
}

# ------------------------------------------------------------------------------
# require_test_sandbox ID: true if this run's sandbox is running; else FAIL, 1
# ------------------------------------------------------------------------------
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
