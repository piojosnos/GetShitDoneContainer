#!/usr/bin/env bash
# H-11: stopping the sandbox is quick and keeps everything.
# - Compose waits 10 s for a stop before it kills, so 10 s or more means the stop was not clean.
# - Ends with the sandbox started again.
# Depends on: nothing
# Needs: test sandbox running; stops and restarts it
set -u
. "$(dirname "$0")/lib.sh"
host_init

sentinelText="h11-$$-$(date +%s)"

# --------------------------------------------------------------------------------
# Writes the two sentinel files
# --------------------------------------------------------------------------------
plant_sentinels() {
  printf '%s\n' "$sentinelText" >"$RUN/hosttest/h11-sentinel.txt"
  printf '%s\n' "$sentinelText" >"$RUN/state/h11-sentinel.txt"
}

# --------------------------------------------------------------------------------
# Takes the sandbox down and times it
# --------------------------------------------------------------------------------
stop_sandbox() {
  startSeconds=$(date +%s)
  compose_down >"$RUN/logs/h11-down.log" 2>&1
  downStatus=$?
  endSeconds=$(date +%s)
  elapsedSeconds=$((endSeconds - startSeconds))
}

# --------------------------------------------------------------------------------
# Checks the down succeeded, took under 10 s and left no container
# --------------------------------------------------------------------------------
check_stop_was_clean() {
  if [ "$downStatus" -ne 0 ]; then
    add_problem "compose down failed (exit $downStatus); log: $RUN/logs/h11-down.log"
  fi

  if [ "$elapsedSeconds" -ge 10 ]; then
    add_problem "compose down took $elapsedSeconds s; 10 s or more means the stop fell through to a kill"
  fi

  if docker container inspect "$CONTAINER" >/dev/null 2>&1 </dev/null; then
    add_problem "$CONTAINER still exists after compose down"
  fi
}

# --------------------------------------------------------------------------------
# Checks the two sentinel files still hold their text
# --------------------------------------------------------------------------------
check_sentinels_intact() {
  local sentinelFile

  for sentinelFile in "$RUN/hosttest/h11-sentinel.txt" "$RUN/state/h11-sentinel.txt"; do
    if [ "$(cat "$sentinelFile" 2>/dev/null)" != "$sentinelText" ]; then
      add_problem "$sentinelFile is missing or changed after the stop"
    fi
  done
}

# --------------------------------------------------------------------------------
# Starts the sandbox again
# --------------------------------------------------------------------------------
start_sandbox_again() {
  if ! compose_up; then
    add_problem "compose up failed after the stop; log: $RUN/logs/compose-up.log"
  fi
}

# --------------------------------------------------------------------------------
# Main / Entry Point
# --------------------------------------------------------------------------------
require_no_arguments "$@" || exit 2
require_test_sandbox H-11 || exit 1
plant_sentinels
stop_sandbox
check_stop_was_clean
check_sentinels_intact
start_sandbox_again
report_check H-11 "stopping is not quick and safe" \
  "compose down took $elapsedSeconds s, the container is gone, the folders are intact"
