#!/usr/bin/env bash
# H-11: stopping the sandbox is quick and keeps everything.
# - Compose waits 10 s for a stop before it kills, so 10 s or more means the stop was not clean.
# - Ends with the sandbox started again.
# Depends on: nothing
# Needs: test sandbox running; stops and restarts it
set -u
. "$(dirname "$0")/lib.sh"
host_init
require_test_sandbox H-11 || exit 1

sentinelText="h11-$$-$(date +%s)"
printf '%s\n' "$sentinelText" >"$RUN/hosttest/h11-sentinel.txt"
printf '%s\n' "$sentinelText" >"$RUN/state/h11-sentinel.txt"

startSeconds=$(date +%s)
compose_down >"$RUN/logs/h11-down.log" 2>&1
downStatus=$?
endSeconds=$(date +%s)
elapsedSeconds=$((endSeconds - startSeconds))

set --

if [ "$downStatus" -ne 0 ]; then
  set -- "$@" "compose down failed (exit $downStatus); log: $RUN/logs/h11-down.log"
fi

if [ "$elapsedSeconds" -ge 10 ]; then
  set -- "$@" "compose down took $elapsedSeconds s; 10 s or more means the stop fell through to a kill"
fi

if docker container inspect "$CONTAINER" >/dev/null 2>&1 </dev/null; then
  set -- "$@" "$CONTAINER still exists after compose down"
fi

for sentinelFile in "$RUN/hosttest/h11-sentinel.txt" "$RUN/state/h11-sentinel.txt"; do
  if [ "$(cat "$sentinelFile" 2>/dev/null)" != "$sentinelText" ]; then
    set -- "$@" "$sentinelFile is missing or changed after the stop"
  fi
done

if ! compose_up; then
  set -- "$@" "compose up failed after the stop; log: $RUN/logs/compose-up.log"
fi

if [ "$#" -gt 0 ]; then
  fail H-11 "stopping is not quick and safe" "$@"
  exit 1
fi

pass H-11 "compose down took $elapsedSeconds s, the container is gone, the folders are intact"
exit 0
