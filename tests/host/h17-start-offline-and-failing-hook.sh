#!/usr/bin/env bash
# ------------------------------------------------------------------------------
# H-17: the sandbox starts offline; a bad or failing start hook stops it
# ------------------------------------------------------------------------------
# Needs: images built; the run folder (not the running sandbox)
# Plain docker run --rm containers on $RUN/h17; the running sandbox stays alone.
# ------------------------------------------------------------------------------
set -u
. "$(dirname "$0")/lib.sh"
. "$(dirname "$0")/lib-bundle.sh"
host_init

# ------------------------------------------------------------------------------
# FAIL and return 1 when there is no run folder
# ------------------------------------------------------------------------------
require_run_folder() {
  if [ -z "${RUN:-}" ]; then
    fail H-17 "no run folder" "run: bash tests/host/run-all.sh first"
    return 1
  fi
}

# ------------------------------------------------------------------------------
# Creates the two bad hook folders; safe to run again on the same folder
# ------------------------------------------------------------------------------
# One holds a hook file with mode 644, the other a link that points nowhere.
# ------------------------------------------------------------------------------
make_hook_folders() {
  mkdir -p "$RUN/h17/hooks-not-executable" "$RUN/h17/hooks-dangling"

  printf '#!/bin/sh\nexit 0\n' >"$RUN/h17/hooks-not-executable/10-not-executable"
  chmod 644 "$RUN/h17/hooks-not-executable/10-not-executable"

  # A relative target dangles on the host and inside the container alike.
  if [ ! -L "$RUN/h17/hooks-dangling/10-dangling" ]; then
    ln -s missing-hook "$RUN/h17/hooks-dangling/10-dangling"
  fi
}

# ------------------------------------------------------------------------------
# Runs one container with the compose restrictions on the h17 folder
# ------------------------------------------------------------------------------
# DOCKER_ARGS adds the per-case flags; the status returned is docker's.
# ------------------------------------------------------------------------------
run_restricted_container() {
  run_timeout 60 docker run --rm --network none --cap-drop ALL --security-opt no-new-privileges:true \
    -e SBX_NAME=hosttest --mount "type=bind,source=$RUN/h17,target=/home/sandbox/workspace" \
    "$@" sbx-claude:local sh -c 'echo h17-command-ran' </dev/null 2>&1
}

# ------------------------------------------------------------------------------
# Runs the offline container, one broken-config container and two bad-hook ones
# ------------------------------------------------------------------------------
# The offline one has --network none. Each bad hook folder is mounted read-only
# over /etc/sbx/start.d, so only its entries are seen.
# ------------------------------------------------------------------------------
run_containers() {
  mkdir -p "$RUN/h17/hosttest" "$RUN/h17/state"

  offlineOutput=$(run_restricted_container)
  offlineStatus=$?

  brokenOutput=$(run_restricted_container -e CLAUDE_CONFIG_DIR=/proc/no-such-dir)
  brokenStatus=$?

  notExecutableOutput=$(run_restricted_container \
    --mount "type=bind,source=$RUN/h17/hooks-not-executable,target=/etc/sbx/start.d,readonly")
  notExecutableStatus=$?

  danglingOutput=$(run_restricted_container \
    --mount "type=bind,source=$RUN/h17/hooks-dangling,target=/etc/sbx/start.d,readonly")
  danglingStatus=$?
}

# ------------------------------------------------------------------------------
# Checks the offline start exited 0 and ran its command
# ------------------------------------------------------------------------------
check_offline_start() {
  if [ "$offlineStatus" -ne 0 ]; then
    add_problem "the offline start exited $offlineStatus; got: $(first_lines "$offlineOutput")"
  fi

  if [[ "$offlineOutput" != *"h17-command-ran"* ]]; then
    add_problem "the offline start did not run its command; got: $(first_lines "$offlineOutput")"
  fi
}

# ------------------------------------------------------------------------------
# Checks the offline start synced GSD at the pin and named no npx
# ------------------------------------------------------------------------------
# state/claude/gsd-core/VERSION equals GSD_CORE_VERSION in versions.env and the
# output holds the line '[sbx] GSD VERSION synced' and no @latest.
# ------------------------------------------------------------------------------
check_offline_gsd() {
  local pin syncedVersion

  pin=$(pin_of GSD_CORE_VERSION)
  syncedVersion=""

  if [ -f "$RUN/h17/state/claude/gsd-core/VERSION" ]; then
    syncedVersion=$(cat "$RUN/h17/state/claude/gsd-core/VERSION")
  fi

  if [ "$syncedVersion" != "$pin" ]; then
    add_problem "the offline start did not sync GSD $pin; state/claude/gsd-core/VERSION holds '$syncedVersion'"
  fi

  if [[ "$offlineOutput" != *"[sbx] GSD $pin synced"* ]]; then
    add_problem "the offline start did not print [sbx] GSD $pin synced; got: $(first_lines "$offlineOutput")"
  fi

  if [[ "$offlineOutput" == *"npx"* || "$offlineOutput" == *"@latest"* ]]; then
    add_problem "the offline start output names npx or @latest: $(first_lines "$offlineOutput")"
  fi
}

# ------------------------------------------------------------------------------
# Checks a failing or bad hook stopped the start and the command never ran
# ------------------------------------------------------------------------------
# Each must exit non-zero with '[sbx] ERROR: start hook' within its 60 s limit;
# a stop by the limit is a failure of the check.
# ------------------------------------------------------------------------------
check_bad_hook_stop() {
  local label=$1 status=$2 output=$3 expectedLine=$4

  if [ "$status" -eq 0 ]; then
    add_problem "$label must exit non-zero; the container exited 0"
  fi

  # 143 and 137 are the statuses run_timeout returns when it stops a command.
  if [ "$status" -eq 143 ] || [ "$status" -eq 137 ]; then
    add_problem "$label did not stop the start within 60 s (exit $status)"
  fi

  if [[ "$output" != *"$expectedLine"* ]]; then
    add_problem "$label must print '$expectedLine'; got: $(first_lines "$output")"
  fi

  if [[ "$output" == *"h17-command-ran"* ]]; then
    add_problem "the command ran despite $label"
  fi
}

# ------------------------------------------------------------------------------
# Main / Entry Point
# ------------------------------------------------------------------------------
require_no_arguments "$@" || exit 2
require_run_folder || exit 1
make_hook_folders
run_containers
check_offline_start
check_offline_gsd
check_bundle_rules_synced "$RUN/h17/state/claude" "the offline start did not sync the rules"
check_bad_hook_stop "a failing start hook" "$brokenStatus" "$brokenOutput" "[sbx] ERROR: start hook"
check_bad_hook_stop "the hook file that is not executable" "$notExecutableStatus" "$notExecutableOutput" \
  "[sbx] ERROR: start hook /etc/sbx/start.d/10-not-executable is not executable; the container was not started."
check_bad_hook_stop "the dangling hook link" "$danglingStatus" "$danglingOutput" \
  "[sbx] ERROR: start hook /etc/sbx/start.d/10-dangling is not a regular file; the container was not started."
report_check H-17 "the offline start or a start hook stop is wrong" \
  "starts and syncs the bundle and GSD $(pin_of GSD_CORE_VERSION) with --network none, naming no npx and no @latest; a failing hook, a hook file that is not executable and a dangling hook link each stop the start with [sbx] ERROR"
