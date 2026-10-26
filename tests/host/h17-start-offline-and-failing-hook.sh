#!/usr/bin/env bash
# ------------------------------------------------------------------------------
# H-17: the sandbox starts offline; a bad or failing start hook stops it
# ------------------------------------------------------------------------------
# Needs: images built; the run folder (not the running sandbox)
# Plain docker run --rm containers; offline with a clone linked, and with none.
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
# Creates the start folders and the clone; safe to run again on the same folder
# ------------------------------------------------------------------------------
# h17 gets a clone and the two bad hook folders (a hook file with mode 644, a
# link that points nowhere); h17-noclone gets no clone.
# ------------------------------------------------------------------------------
make_start_folders() {
  mkdir -p "$RUN/h17/hooks-not-executable" "$RUN/h17/hooks-dangling" "$RUN/h17/hosttest" "$RUN/h17/state"
  mkdir -p "$RUN/h17-noclone/hosttest" "$RUN/h17-noclone/state"

  if [ ! -d "$RUN/h17/best-practices" ]; then
    if ! make_bundle_clone "$RUN/bundle-origin.git" "$RUN/h17/best-practices" >/dev/null 2>&1; then
      add_problem "could not clone $RUN/bundle-origin.git into $RUN/h17/best-practices"
    fi
  fi

  printf '#!/bin/sh\nexit 0\n' >"$RUN/h17/hooks-not-executable/10-not-executable"
  chmod 644 "$RUN/h17/hooks-not-executable/10-not-executable"

  # A relative target dangles on the host and inside the container alike.
  if [ ! -L "$RUN/h17/hooks-dangling/10-dangling" ]; then
    ln -s missing-hook "$RUN/h17/hooks-dangling/10-dangling"
  fi
}

# ------------------------------------------------------------------------------
# Runs one container with the compose restrictions on a folder
# ------------------------------------------------------------------------------
# run_restricted_container FOLDER [DOCKER_ARG...] mounts FOLDER at
# /home/sandbox/workspace; the DOCKER_ARGs add the per-case flags.
# ------------------------------------------------------------------------------
run_restricted_container() {
  local folder=$1

  shift
  run_timeout 60 docker run --rm --network none --cap-drop ALL --security-opt no-new-privileges:true \
    -e SBX_NAME=hosttest --mount "type=bind,source=$folder,target=/home/sandbox/workspace" \
    "$@" sbx-claude:local sh -c 'echo h17-command-ran' </dev/null 2>&1
}

# ------------------------------------------------------------------------------
# Runs two offline containers, one broken-config one and two bad-hook ones
# ------------------------------------------------------------------------------
# The offline ones have --network none: one with the clone, one with none.
# Each bad hook folder is mounted read-only over /etc/sbx/start.d.
# ------------------------------------------------------------------------------
run_containers() {
  offlineOutput=$(run_restricted_container "$RUN/h17")
  offlineStatus=$?

  noCloneOutput=$(run_restricted_container "$RUN/h17-noclone")
  noCloneStatus=$?

  brokenOutput=$(run_restricted_container "$RUN/h17" -e CLAUDE_CONFIG_DIR=/proc/no-such-dir)
  brokenStatus=$?

  notExecutableOutput=$(run_restricted_container "$RUN/h17" \
    --mount "type=bind,source=$RUN/h17/hooks-not-executable,target=/etc/sbx/start.d,readonly")
  notExecutableStatus=$?

  danglingOutput=$(run_restricted_container "$RUN/h17" \
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
# Checks the offline start linked the clone it found
# ------------------------------------------------------------------------------
check_offline_links() {
  check_bundle_links "$RUN/h17/state/claude" "$RUN/h17/best-practices"

  if [[ "$offlineOutput" != *"[sbx] best-practices linked from /home/sandbox/workspace/best-practices"* ]]; then
    add_problem "the offline start did not print the linked line; got: $(first_lines "$offlineOutput")"
  fi
}

# ------------------------------------------------------------------------------
# Checks a start with no clone exits 0, runs its command and says what to run
# ------------------------------------------------------------------------------
check_offline_without_clone() {
  if [ "$noCloneStatus" -ne 0 ]; then
    add_problem "the start with no clone exited $noCloneStatus; got: $(first_lines "$noCloneOutput")"
  fi

  if [[ "$noCloneOutput" != *"h17-command-ran"* ]]; then
    add_problem "the start with no clone did not run its command; got: $(first_lines "$noCloneOutput")"
  fi

  if [[ "$noCloneOutput" != *"[sbx] no best-practices clone at /home/sandbox/workspace/best-practices; run sbx-bundle-clone"* ]]; then
    add_problem "the start with no clone did not print the no-clone line; got: $(first_lines "$noCloneOutput")"
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
make_start_folders
run_containers
check_offline_start
check_offline_gsd
check_offline_links
check_offline_without_clone
check_bad_hook_stop "a failing start hook" "$brokenStatus" "$brokenOutput" "[sbx] ERROR: start hook"
check_bad_hook_stop "the hook file that is not executable" "$notExecutableStatus" "$notExecutableOutput" \
  "[sbx] ERROR: start hook /etc/sbx/start.d/10-not-executable is not executable; the container was not started."
check_bad_hook_stop "the dangling hook link" "$danglingStatus" "$danglingOutput" \
  "[sbx] ERROR: start hook /etc/sbx/start.d/10-dangling is not a regular file; the container was not started."
report_check H-17 "the offline start or a start hook stop is wrong" \
  "starts with --network none, syncs GSD $(pin_of GSD_CORE_VERSION) naming no npx and no @latest, and links a clone that is there; starts with no clone and says to run sbx-bundle-clone; a failing hook, a hook file that is not executable and a dangling hook link each stop the start with [sbx] ERROR"
