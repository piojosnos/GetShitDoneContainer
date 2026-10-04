#!/usr/bin/env bash
# H-10: starting the sandbox on a folder that does not exist is refused.
# - The missing folder is $RUN/does-not-exist, so the printed cleanup removes it if Docker creates it.
# - Three outcomes, three different lines:
#     refused and the folder was not created                    PASS
#     refused, but Docker created the folder (the flag ignored) FAIL
#     the sandbox started on the missing folder                 FAIL
# - A FAIL here can be a correct report about Docker Compose. The script never edits
#   compose.yml and never removes the folder.
# - Always ends with the real test sandbox started again.
# Depends on: nothing
# Needs: test sandbox running; stops and restarts it
set -u
. "$(dirname "$0")/lib.sh"
host_init
require_test_sandbox H-10 || exit 1

badDir="$RUN/does-not-exist"
composeVersion=$(docker compose version --short </dev/null 2>/dev/null)
restartNote=""

if ! compose_down >"$RUN/logs/h10-down.log" 2>&1; then
  fail H-10 "compose down failed before the test; log: $RUN/logs/h10-down.log"
  exit 1
fi

upOutput=$(run_timeout 120 env SBX_NAME=hosttest SBX_DIR="$badDir" docker compose -f "$REPO_DIR/compose.yml" up -d --wait </dev/null 2>&1)
upStatus=$?
pathExists=0
if [ -e "$badDir" ]; then
  pathExists=1
fi

compose_down >"$RUN/logs/h10-down-after.log" 2>&1
if ! compose_up; then
  restartNote=" The real test sandbox did not start again (log: $RUN/logs/compose-up.log)."
fi

lastLines=$(printf '%s\n' "$upOutput" | tail -n 3 | tr '\n' ' ')

if [ "$upStatus" -eq 0 ]; then
  fail H-10 "the sandbox started on a missing folder (rc=0). Compose $composeVersion.$restartNote" \
    "the path was $badDir; last output: $lastLines"
  exit 1
fi

if [ "$pathExists" -eq 1 ]; then
  fail H-10 "Docker created $badDir (create_host_path ignored); the entrypoint still refused (rc=$upStatus). Compose $composeVersion.$restartNote" \
    "last output: $lastLines" \
    "the printed cleanup removes the run folder, and the path with it"
  exit 1
fi

if [ -n "$restartNote" ]; then
  fail H-10 "refused as expected (rc=$upStatus), but the real sandbox did not come back.$restartNote"
  exit 1
fi

pass H-10 "a missing folder is refused (rc=$upStatus) and not created. Compose $composeVersion"
exit 0
