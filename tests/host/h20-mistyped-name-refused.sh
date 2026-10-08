#!/usr/bin/env bash
# H-20: a sandbox folder without the project folder (a mistyped SBX_NAME) is refused, and nothing is created on the host.
# - The sandbox folder is $RUN/h20. It holds state/ but no hosttest/ folder; the container name stays sbx-hosttest.
# - Four outcomes, four different lines:
#     refused, nothing created, the log names the missing project folder   PASS
#     the sandbox started without a project folder                         FAIL
#     refused, but the project folder was created on the host              FAIL
#     refused, but the container log does not name the missing folder      FAIL
# - A FAIL here can be a correct report about Docker. The script never edits compose.yml and
#   never removes the folder.
# - Always ends with the real test sandbox started again.
# Depends on: nothing
# Needs: test sandbox running; stops and restarts it
set -u
. "$(dirname "$0")/lib.sh"
host_init

h20Dir="$RUN/h20"
composeVersion=$(docker compose version --short </dev/null 2>/dev/null)
restartNote=""

# --------------------------------------------------------------------------------
# Takes the test sandbox down before the test; FAIL and return 1 if that fails
# --------------------------------------------------------------------------------
stop_sandbox_first() {
  if ! compose_down >"$RUN/logs/h20-down.log" 2>&1; then
    fail H-20 "compose down failed before the test; log: $RUN/logs/h20-down.log"
    return 1
  fi
}

# --------------------------------------------------------------------------------
# Tries to start a sandbox on a folder without the project folder; keeps the container log and notes whether the project folder was created
# --------------------------------------------------------------------------------
try_start_without_project_folder() {
  mkdir -p "$h20Dir/state"
  upOutput=$(run_timeout 120 env SBX_NAME=hosttest SBX_DIR="$h20Dir" docker compose --env-file /dev/null -f "$REPO_DIR/compose.yml" up -d --wait </dev/null 2>&1)
  upStatus=$?
  logOutput=$(docker logs "$CONTAINER" </dev/null 2>&1)
  projectCreated=0

  if [ -e "$h20Dir/hosttest" ]; then
    projectCreated=1
  fi
}

# --------------------------------------------------------------------------------
# Starts the real test sandbox again, whatever happened
# --------------------------------------------------------------------------------
restart_real_sandbox() {
  compose_down >"$RUN/logs/h20-down-after.log" 2>&1

  if ! compose_up; then
    restartNote=" The real test sandbox did not start again (log: $RUN/logs/compose-up.log)."
  fi
}

# --------------------------------------------------------------------------------
# Reports one of the outcomes; see the header
# --------------------------------------------------------------------------------
report_outcome() {
  local logLines projectNow

  logLines=$(printf '%s\n' "$logOutput" | head -n 3 | tr '\n' ' ')

  if [ "$upStatus" -eq 0 ]; then
    projectNow=no

    if [ "$projectCreated" -eq 1 ]; then
      projectNow=yes
    fi

    fail H-20 "the sandbox started although the sandbox folder has no hosttest/ folder (rc=0).$restartNote" \
      "the project folder now exists: $projectNow. Compose $composeVersion"
    return 1
  fi

  if [ "$projectCreated" -eq 1 ]; then
    fail H-20 "the start was refused (rc=$upStatus), but $h20Dir/hosttest was created on the host.$restartNote" \
      "Compose $composeVersion; the printed cleanup removes the run folder, and the folder with it"
    return 1
  fi

  if ! printf '%s\n' "$logOutput" | grep -Fq -- "(the project folder) is missing"; then
    fail H-20 "the start was refused (rc=$upStatus), but the container log does not say the project folder is missing.$restartNote" \
      "first log lines: $logLines"
    return 1
  fi

  if [ -n "$restartNote" ]; then
    fail H-20 "refused as expected (rc=$upStatus), but the real sandbox did not come back.$restartNote"
    return 1
  fi

  pass H-20 "a sandbox folder without the project folder is refused (rc=$upStatus), nothing is created, and the log names the missing folder"
}

# --------------------------------------------------------------------------------
# Main / Entry Point
# --------------------------------------------------------------------------------
require_no_arguments "$@" || exit 2
require_test_sandbox H-20 || exit 1
stop_sandbox_first || exit 1
try_start_without_project_folder
restart_real_sandbox
report_outcome || exit 1
