#!/usr/bin/env bash
# ------------------------------------------------------------------------------
# H-28: sbx-add registers a sandbox once; sbx-start and sbx-stop work by name
# ------------------------------------------------------------------------------
# Needs: test sandbox running; takes it down and restores it
# The real scripts run with /bin/bash on a folder with a space in its path.
# ------------------------------------------------------------------------------
set -u
. "$(dirname "$0")/lib.sh"
host_init
. "$(dirname "$0")/lib-sbx.sh"

sentinelText="h28-$$-$(date +%s)"
entryFile=""
firstId=""
sbxDir=""
sbxPath=""
sbxStatus=0

# ------------------------------------------------------------------------------
# Takes the test sandbox down; FAIL and return 1 if that fails
# ------------------------------------------------------------------------------
take_sandbox_down() {
  if ! compose_down >"$RUN/logs/h28-down.log" 2>&1; then
    fail H-28 "compose down failed before the test; log: $RUN/logs/h28-down.log"
    return 1
  fi
}

# ------------------------------------------------------------------------------
# Checks that the scripts are found through PATH
# ------------------------------------------------------------------------------
# A lost exec bit or a broken shebang fails here.
# ------------------------------------------------------------------------------
check_lookup() {
  local found

  found=$(PATH="$sbxPath" command -v sbx-add)

  if [ "$found" != "$REPO_DIR/bin/sbx-add" ]; then
    add_problem "sbx-add was not found through PATH as $REPO_DIR/bin/sbx-add (got: ${found:-nothing})"
  fi
}

# ------------------------------------------------------------------------------
# Checks sbx-add: the entry, the folders, and the refusal of a second run
# ------------------------------------------------------------------------------
check_add() {
  entryFile=$SBX_CONFIG_DIR/sandboxes/hosttest

  run_sbx h28-add sbx-add hosttest "$sbxDir"

  if [ "$sbxStatus" -ne 0 ]; then
    add_problem "sbx-add exited $sbxStatus; log: $RUN/logs/h28-add.err"
  fi

  if ! printf 'SBX_DIR=%s\nSBX_AGENT=claude\n' "$sbxDir" | cmp -s - "$entryFile"; then
    add_problem "the entry $entryFile is not the two lines SBX_DIR and SBX_AGENT=claude"
  fi

  if [ ! -d "$sbxDir/hosttest" ] || [ ! -d "$sbxDir/state" ]; then
    add_problem "sbx-add did not make $sbxDir/hosttest and $sbxDir/state"
  fi

  run_sbx h28-add-again sbx-add hosttest "$sbxDir"

  if [ "$sbxStatus" -ne 1 ]; then
    add_problem "a second sbx-add exited $sbxStatus, not 1; log: $RUN/logs/h28-add-again.err"
  fi

  if ! printf 'SBX_DIR=%s\nSBX_AGENT=claude\n' "$sbxDir" | cmp -s - "$entryFile"; then
    add_problem "the second sbx-add changed the entry $entryFile"
  fi
}

# ------------------------------------------------------------------------------
# Checks that sbx-stop of a sandbox that was never started exits 0
# ------------------------------------------------------------------------------
check_stop_before_start() {
  run_sbx h28-stop-first sbx-stop hosttest

  if [ "$sbxStatus" -ne 0 ]; then
    add_problem "sbx-stop before any start exited $sbxStatus; log: $RUN/logs/h28-stop-first.err"
  fi
}

# ------------------------------------------------------------------------------
# Checks sbx-start: running, on the registered folder, in the right project
# ------------------------------------------------------------------------------
# The exported COMPOSE_PROJECT_NAME of run_sbx must have been ignored.
# ------------------------------------------------------------------------------
check_start() {
  local mountSource
  local projectLabel

  printf '%s\n' "$sentinelText" >"$sbxDir/hosttest/h28-sentinel.txt"
  printf '%s\n' "$sentinelText" >"$sbxDir/state/h28-sentinel.txt"

  run_sbx h28-start sbx-start hosttest

  if [ "$sbxStatus" -ne 0 ]; then
    add_problem "sbx-start exited $sbxStatus; log: $RUN/logs/h28-start.err"
  fi

  if [ "$(sandbox_field '{{.State.Running}}')" != "true" ]; then
    add_problem "$CONTAINER is not running after sbx-start"
  fi

  mountSource=$(sandbox_mount_source)

  case "$mountSource" in
    */"$(basename "$sbxDir")")
      ;;
    *)
      add_problem "the workspace mount source is '$mountSource', not the registered folder '$sbxDir'"
      ;;
  esac

  projectLabel=$(sandbox_field '{{index .Config.Labels "com.docker.compose.project"}}')

  if [ "$projectLabel" != "sbx-hosttest" ]; then
    add_problem "the Compose project is '$projectLabel', not sbx-hosttest; the exported COMPOSE_PROJECT_NAME was not ignored"
  fi

  if ! docker exec "$CONTAINER" pgrep -x sleep >/dev/null 2>&1 </dev/null; then
    add_problem "the start hooks of $CONTAINER are not done after sbx-start returned"
  fi

  if [ "$(in_container cat /home/sandbox/workspace/hosttest/h28-sentinel.txt)" != "$sentinelText" ]; then
    add_problem "the project folder in the container does not hold the sentinel written on the host"
  fi

  firstId=$(sandbox_field '{{.Id}}')
}

# ------------------------------------------------------------------------------
# Checks sbx-stop: container kept, stopped, files unchanged, a second stop is ok
# ------------------------------------------------------------------------------
check_stop() {
  local sentinelFile

  run_sbx h28-stop sbx-stop hosttest

  if [ "$sbxStatus" -ne 0 ]; then
    add_problem "sbx-stop exited $sbxStatus; log: $RUN/logs/h28-stop.err"
  fi

  if [ "$(sandbox_field '{{.State.Running}}')" != "false" ]; then
    add_problem "$CONTAINER is missing or still running after sbx-stop"
  fi

  for sentinelFile in "$sbxDir/hosttest/h28-sentinel.txt" "$sbxDir/state/h28-sentinel.txt"; do
    if [ "$(cat "$sentinelFile" 2>/dev/null)" != "$sentinelText" ]; then
      add_problem "$sentinelFile is missing or changed after sbx-stop"
    fi
  done

  run_sbx h28-stop-again sbx-stop hosttest

  if [ "$sbxStatus" -ne 0 ]; then
    add_problem "a second sbx-stop exited $sbxStatus; log: $RUN/logs/h28-stop-again.err"
  fi
}

# ------------------------------------------------------------------------------
# Checks that the next sbx-start reuses the same container
# ------------------------------------------------------------------------------
check_start_again() {
  run_sbx h28-start-again sbx-start hosttest

  if [ "$sbxStatus" -ne 0 ]; then
    add_problem "the second sbx-start exited $sbxStatus; log: $RUN/logs/h28-start-again.err"
  fi

  if [ "$(sandbox_field '{{.State.Running}}')" != "true" ]; then
    add_problem "$CONTAINER is not running after the second sbx-start"
  fi

  if [ -z "$firstId" ] || [ "$(sandbox_field '{{.Id}}')" != "$firstId" ]; then
    add_problem "the second sbx-start did not reuse the container of the first"
  fi
}

# ------------------------------------------------------------------------------
# Checks that sbx-start of a running sandbox on the current image is silent
# ------------------------------------------------------------------------------
# The older-image warning compares two image ids; a false warning here would mean
# the ids are not comparable on this Docker.
# ------------------------------------------------------------------------------
check_start_running() {
  run_sbx h28-start-running sbx-start hosttest

  if [ "$sbxStatus" -ne 0 ]; then
    add_problem "sbx-start of the running sandbox exited $sbxStatus; log: $RUN/logs/h28-start-running.err"
  fi

  if grep -qF 'older image' "$RUN/logs/h28-start-running.out"; then
    add_problem "sbx-start warned about an older image for a sandbox on the current image; log: $RUN/logs/h28-start-running.out"
  fi

  if [ -z "$firstId" ] || [ "$(sandbox_field '{{.Id}}')" != "$firstId" ]; then
    add_problem "sbx-start of the running sandbox recreated the container"
  fi
}

# ------------------------------------------------------------------------------
# Main / Entry Point
# ------------------------------------------------------------------------------
require_no_arguments "$@" || exit 2
require_test_sandbox H-28 || exit 1
sbx_test_setup H-28 h28 || exit 1
take_sandbox_down || exit 1
check_lookup
check_add
check_stop_before_start
check_start
check_stop
check_start_again
check_start_running
restore_test_sandbox h28
report_check H-28 "the sbx scripts did not register, start or stop the sandbox by name" \
  "sbx-add registered a folder with a space and refused it twice; sbx-start and sbx-stop worked by name with /bin/bash; the container and the files stayed; sbx-start of a running sandbox on the current image printed no warning"
