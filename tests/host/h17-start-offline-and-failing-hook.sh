#!/usr/bin/env bash
# H-17: the sandbox starts with networking disabled, and a failing start hook stops the start.
# - Offline start: a container with --network none syncs the bundle and runs its command.
# - Failing hook: a container whose config folder cannot be made exits non-zero with
#   '[sbx] ERROR: start hook' and never runs its command.
# - Both are plain docker run --rm containers with the compose restrictions, mounting their own
#   folder $RUN/h17, so the running test sandbox is not touched.
# Depends on: nothing
# Needs: images built; the run folder (not the running sandbox)
set -u
. "$(dirname "$0")/lib.sh"
host_init

# --------------------------------------------------------------------------------
# Stops the check when there is no run folder
# --------------------------------------------------------------------------------
require_run_folder() {
  if [ -z "${RUN:-}" ]; then
    fail H-17 "no run folder" "run: bash tests/host/run-all.sh first"
    exit 1
  fi
}

# --------------------------------------------------------------------------------
# Runs one offline container and one with a broken config folder; keeps their output and status
# --------------------------------------------------------------------------------
run_containers() {
  mkdir -p "$RUN/h17/hosttest" "$RUN/h17/state"

  offlineOutput=$(run_timeout 60 docker run --rm --network none --cap-drop ALL --security-opt no-new-privileges:true -e SBX_NAME=hosttest --mount "type=bind,source=$RUN/h17,target=/home/sandbox/workspace" sbx-claude:local sh -c 'echo h17-command-ran' </dev/null 2>&1)
  offlineStatus=$?

  brokenOutput=$(run_timeout 60 docker run --rm --network none --cap-drop ALL --security-opt no-new-privileges:true -e SBX_NAME=hosttest -e CLAUDE_CONFIG_DIR=/proc/no-such-dir --mount "type=bind,source=$RUN/h17,target=/home/sandbox/workspace" sbx-claude:local sh -c 'echo h17-command-ran' </dev/null 2>&1)
  brokenStatus=$?
}

# --------------------------------------------------------------------------------
# Checks both starts, then prints PASS or FAIL and exits
# --------------------------------------------------------------------------------
check_and_report() {
  local rulesDiff

  set --

  if [ "$offlineStatus" -ne 0 ]; then
    set -- "$@" "the offline start exited $offlineStatus; got: $(printf '%s\n' "$offlineOutput" | head -n 3 | tr '\n' ' ')"
  fi

  if [[ "$offlineOutput" != *"h17-command-ran"* ]]; then
    set -- "$@" "the offline start did not run its command; got: $(printf '%s\n' "$offlineOutput" | head -n 3 | tr '\n' ' ')"
  fi

  rulesDiff=$(diff -r -x .DS_Store "$REPO_DIR/best-practices/rules" "$RUN/h17/state/claude/rules" 2>&1)

  if [ "$?" -ne 0 ]; then
    set -- "$@" "the offline start did not sync the rules: $(printf '%s\n' "$rulesDiff" | head -n 3 | tr '\n' ' ')"
  fi

  if [ "$brokenStatus" -eq 0 ]; then
    set -- "$@" "a failing start hook must exit non-zero; the container exited 0"
  fi

  if [[ "$brokenOutput" != *"[sbx] ERROR: start hook"* ]]; then
    set -- "$@" "a failing start hook must print '[sbx] ERROR: start hook'; got: $(printf '%s\n' "$brokenOutput" | head -n 3 | tr '\n' ' ')"
  fi

  if [[ "$brokenOutput" == *"h17-command-ran"* ]]; then
    set -- "$@" "the command ran although the start hook failed"
  fi

  if [ "$#" -gt 0 ]; then
    fail H-17 "the offline start or the failing-hook stop is wrong" "$@"
    exit 1
  fi

  pass H-17 "starts and syncs with --network none; a failing start hook stops the start with [sbx] ERROR"
  exit 0
}

# --------------------------------------------------------------------------------
# Main / Entry Point
# --------------------------------------------------------------------------------
require_run_folder
run_containers
check_and_report
