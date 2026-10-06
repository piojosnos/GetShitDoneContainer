#!/usr/bin/env bash
# H-08: shell history is written after each command and survives a recreate.
# - A non-tty bash -i is held open in the background (the first shell of the manual check).
# - The marker must reach the history file on the host while that shell is still open.
# - Then the sandbox is taken down and started again, and a fresh shell must show the marker.
# - The background pipeline is detached and never waited for; the recreate ends it.
# Depends on: nothing
# Needs: test sandbox running; stops and restarts it
set -u
. "$(dirname "$0")/lib.sh"
host_init
require_test_sandbox H-08 || exit 1

marker="marker-$$-$(date +%s)"
historyFile="$RUN/state/shell/bash_history"

# --------------------------------------------------------------------------------
# Opens a shell in the background that echoes the marker and stays open
# --------------------------------------------------------------------------------
start_background_shell() {
  ( ( printf 'echo %s\n' "$marker"; sleep 25 ) | docker exec -i "$CONTAINER" bash -i ) >/dev/null 2>&1 &
}

# --------------------------------------------------------------------------------
# Waits up to 10 s for the marker to reach the history file on the host; FAIL and return 1 if it never does
# --------------------------------------------------------------------------------
wait_for_marker() {
  local seen i

  seen=0
  for i in 1 2 3 4 5 6 7 8 9 10; do
    if grep -Fq "$marker" "$historyFile" 2>/dev/null; then
      seen=1
      break
    fi
    sleep 1
  done

  if [ "$seen" -eq 0 ]; then
    fail H-08 "the marker did not reach the history file before the recreate" \
      "looked for $marker in $historyFile for 10 s while the first shell was open"
    return 1
  fi
}

# --------------------------------------------------------------------------------
# Checks a fresh shell shows the marker after the recreate
# --------------------------------------------------------------------------------
check_fresh_shell_history() {
  local freshOutput markerCount

  freshOutput=$(printf 'history\nexit\n' | docker exec -i "$CONTAINER" bash -i 2>/dev/null)
  markerCount=$(printf '%s\n' "$freshOutput" | grep -Fc "$marker")

  if [ "$markerCount" -lt 1 ]; then
    add_problem "the history file on the host has it: $(grep -Fc "$marker" "$historyFile" 2>/dev/null)"
    add_problem "history output started with: $(first_lines "$freshOutput")"
  fi
}

# --------------------------------------------------------------------------------
# Main / Entry Point
# --------------------------------------------------------------------------------
start_background_shell
wait_for_marker || exit 1
restart_test_sandbox H-08 h08-down.log || exit 1
check_fresh_shell_history
report_check H-08 "the marker is not in a fresh shell's history after the recreate" \
  "history was written while the shell was open and a fresh shell shows it after the recreate"
