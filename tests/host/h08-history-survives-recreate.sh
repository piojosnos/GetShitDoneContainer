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

( ( printf 'echo %s\n' "$marker"; sleep 25 ) | docker exec -i "$CONTAINER" bash -i ) >/dev/null 2>&1 &

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
  exit 1
fi

if ! compose_down >"$RUN/logs/h08-down.log" 2>&1; then
  fail H-08 "compose down failed" "log: $RUN/logs/h08-down.log"
  exit 1
fi

if ! compose_up; then
  fail H-08 "compose up failed after the down" "log: $RUN/logs/compose-up.log"
  exit 1
fi

freshOutput=$(printf 'history\nexit\n' | docker exec -i "$CONTAINER" bash -i 2>/dev/null)
markerCount=$(printf '%s\n' "$freshOutput" | grep -Fc "$marker")

if [ "$markerCount" -lt 1 ]; then
  fail H-08 "the marker is not in a fresh shell's history after the recreate" \
    "the history file on the host has it: $(grep -Fc "$marker" "$historyFile" 2>/dev/null)" \
    "history output started with: $(printf '%s\n' "$freshOutput" | head -n 3 | tr '\n' ' ')"
  exit 1
fi

pass H-08 "history was written while the shell was open and a fresh shell shows it after the recreate"
exit 0
