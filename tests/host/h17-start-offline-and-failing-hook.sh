#!/usr/bin/env bash
# H-17: the sandbox starts with networking disabled, and a bad or failing start hook stops the start.
# - Offline start: a container with --network none syncs the bundle and runs its command.
# - Failing hook: a container whose config folder cannot be made exits non-zero with
#   '[sbx] ERROR: start hook' and never runs its command.
# - Bad hook folders: two more containers each mount their own folder under $RUN/h17 over
#   /etc/sbx/start.d, read-only, so only that folder's entries are seen. One holds a hook file with
#   mode 644, the other a link that points nowhere. Each must exit non-zero with its
#   '[sbx] ERROR: start hook' line ('is not executable' or 'is not a regular file') and never run
#   its command.
# - All four are plain docker run --rm containers with the compose restrictions, mounting their
#   own folder $RUN/h17, so the running test sandbox is not touched.
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
    stop_check H-17 "no run folder" "run: bash tests/host/run-all.sh first"
  fi
}

# --------------------------------------------------------------------------------
# Creates the two bad hook folders; safe to run again on the same run folder
# --------------------------------------------------------------------------------
make_hook_folders() {
  mkdir -p "$RUN/h17/hooks-not-executable" "$RUN/h17/hooks-dangling"

  printf '#!/bin/sh\nexit 0\n' >"$RUN/h17/hooks-not-executable/10-not-executable"
  chmod 644 "$RUN/h17/hooks-not-executable/10-not-executable"

  # A relative target dangles on the host and inside the container alike.
  if [ ! -L "$RUN/h17/hooks-dangling/10-dangling" ]; then
    ln -s missing-hook "$RUN/h17/hooks-dangling/10-dangling"
  fi
}

# --------------------------------------------------------------------------------
# Runs one container whose own hook folder replaces /etc/sbx/start.d; its status is docker's
# --------------------------------------------------------------------------------
run_with_hook_folder() {
  run_timeout 60 docker run --rm --network none --cap-drop ALL --security-opt no-new-privileges:true -e SBX_NAME=hosttest --mount "type=bind,source=$RUN/h17,target=/home/sandbox/workspace" --mount "type=bind,source=$1,target=/etc/sbx/start.d,readonly" sbx-claude:local sh -c 'echo h17-command-ran' </dev/null 2>&1
}

# --------------------------------------------------------------------------------
# Runs the offline container, one with a broken config folder and two with bad hook folders
# --------------------------------------------------------------------------------
run_containers() {
  mkdir -p "$RUN/h17/hosttest" "$RUN/h17/state"

  offlineOutput=$(run_timeout 60 docker run --rm --network none --cap-drop ALL --security-opt no-new-privileges:true -e SBX_NAME=hosttest --mount "type=bind,source=$RUN/h17,target=/home/sandbox/workspace" sbx-claude:local sh -c 'echo h17-command-ran' </dev/null 2>&1)
  offlineStatus=$?

  brokenOutput=$(run_timeout 60 docker run --rm --network none --cap-drop ALL --security-opt no-new-privileges:true -e SBX_NAME=hosttest -e CLAUDE_CONFIG_DIR=/proc/no-such-dir --mount "type=bind,source=$RUN/h17,target=/home/sandbox/workspace" sbx-claude:local sh -c 'echo h17-command-ran' </dev/null 2>&1)
  brokenStatus=$?

  notExecutableOutput=$(run_with_hook_folder "$RUN/h17/hooks-not-executable")
  notExecutableStatus=$?

  danglingOutput=$(run_with_hook_folder "$RUN/h17/hooks-dangling")
  danglingStatus=$?
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
# Checks a bad hook folder stopped the start with the expected error and never ran the command
# --------------------------------------------------------------------------------
check_bad_hook_stop() {
  local label=$1 status=$2 output=$3 expectedLine=$4

  if [ "$status" -eq 0 ]; then
    add_problem "$label must exit non-zero; the container exited 0"
  fi

  if [[ "$output" != *"$expectedLine"* ]]; then
    add_problem "$label must print '$expectedLine'; got: $(first_lines "$output")"
  fi

  if [[ "$output" == *"h17-command-ran"* ]]; then
    add_problem "the command ran although $label"
  fi
}

# --------------------------------------------------------------------------------
# Main / Entry Point
# --------------------------------------------------------------------------------
require_run_folder
make_hook_folders
run_containers
check_offline_start
check_bundle_rules_synced "$RUN/h17/state/claude" "the offline start did not sync the rules"
check_failing_hook
check_bad_hook_stop "the hook file that is not executable" "$notExecutableStatus" "$notExecutableOutput" \
  "[sbx] ERROR: start hook /etc/sbx/start.d/10-not-executable is not executable; the container was not started."
check_bad_hook_stop "the dangling hook link" "$danglingStatus" "$danglingOutput" \
  "[sbx] ERROR: start hook /etc/sbx/start.d/10-dangling is not a regular file; the container was not started."
report_check H-17 "the offline start or a start hook stop is wrong" \
  "starts and syncs with --network none; a failing hook, a hook file that is not executable and a dangling hook link each stop the start with [sbx] ERROR"
