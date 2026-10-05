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
. "$(dirname "$0")/lib-bundle.sh"
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
# Checks the offline start exited 0 and ran its command
# --------------------------------------------------------------------------------
check_offline_start() {
  if [ "$offlineStatus" -ne 0 ]; then
    add_problem "the offline start exited $offlineStatus; got: $(first_lines "$offlineOutput")"
  fi

  if [[ "$offlineOutput" != *"h17-command-ran"* ]]; then
    add_problem "the offline start did not run its command; got: $(first_lines "$offlineOutput")"
  fi
}

# --------------------------------------------------------------------------------
# Checks the failing start hook stopped the start with an error and never ran the command
# --------------------------------------------------------------------------------
check_failing_hook() {
  if [ "$brokenStatus" -eq 0 ]; then
    add_problem "a failing start hook must exit non-zero; the container exited 0"
  fi

  if [[ "$brokenOutput" != *"[sbx] ERROR: start hook"* ]]; then
    add_problem "a failing start hook must print '[sbx] ERROR: start hook'; got: $(first_lines "$brokenOutput")"
  fi

  if [[ "$brokenOutput" == *"h17-command-ran"* ]]; then
    add_problem "the command ran although the start hook failed"
  fi
}

# --------------------------------------------------------------------------------
# Main / Entry Point
# --------------------------------------------------------------------------------
require_run_folder
run_containers
check_offline_start
check_bundle_rules_synced "$RUN/h17/state/claude" "the offline start did not sync the rules"
check_failing_hook
report_check H-17 "the offline start or the failing-hook stop is wrong" \
  "starts and syncs with --network none; a failing start hook stops the start with [sbx] ERROR"
