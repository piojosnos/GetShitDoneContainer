#!/usr/bin/env bash
# ------------------------------------------------------------------------------
# H-29: sbx-upgrade rebuilds, recreates one sandbox and keeps its files
# ------------------------------------------------------------------------------
# Needs: test sandbox running; takes it down and restores it
# A bogus build option proves a failed build leaves the sandbox as it was.
# ------------------------------------------------------------------------------
set -u
. "$(dirname "$0")/lib.sh"
host_init
. "$(dirname "$0")/lib-sbx.sh"

sentinelText="h29-$$-$(date +%s)"
sbxDir=""
sbxPath=""
sbxStatus=0
idBefore=""
startBefore=""
volumesBefore=""
othersBefore=""

# ------------------------------------------------------------------------------
# list_project_volumes: the volume names of the Compose project sbx-hosttest
# ------------------------------------------------------------------------------
list_project_volumes() {
  docker volume ls -q --filter label=com.docker.compose.project=sbx-hosttest </dev/null 2>&1
}

# ------------------------------------------------------------------------------
# list_other_containers: name, id and state of every sbx- container but ours
# ------------------------------------------------------------------------------
list_other_containers() {
  docker ps -a --filter name=sbx- --format '{{.Names}} {{.ID}} {{.State}}' </dev/null 2>&1 | grep -v '^sbx-hosttest ' | sort || true
}

# ------------------------------------------------------------------------------
# Registers the test sandbox on its own folder and starts it by name
# ------------------------------------------------------------------------------
prepare() {
  if ! compose_down >"$RUN/logs/h29-down.log" 2>&1; then
    fail H-29 "compose down failed before the test; log: $RUN/logs/h29-down.log"
    return 1
  fi

  run_sbx h29-add sbx-add hosttest "$sbxDir"

  if [ "$sbxStatus" -ne 0 ]; then
    fail H-29 "sbx-add exited $sbxStatus; log: $RUN/logs/h29-add.err"
    restore_test_sandbox h29
    return 1
  fi

  run_sbx h29-start sbx-start hosttest

  if [ "$sbxStatus" -ne 0 ]; then
    fail H-29 "sbx-start exited $sbxStatus; log: $RUN/logs/h29-start.err"
    restore_test_sandbox h29
    return 1
  fi
}

# ------------------------------------------------------------------------------
# Checks that a failed build leaves the running sandbox as it was
# ------------------------------------------------------------------------------
check_failed_build() {
  idBefore=$(sandbox_field '{{.Id}}')
  startBefore=$(sandbox_field '{{.State.StartedAt}}')

  run_sbx h29-bad-build sbx-upgrade hosttest --no-such-option

  if [ "$sbxStatus" -eq 0 ]; then
    add_problem "sbx-upgrade with a bogus build option exited 0; log: $RUN/logs/h29-bad-build.out"
  fi

  if ! grep -qF 'the build failed' "$RUN/logs/h29-bad-build.err"; then
    add_problem "the failed build did not print 'the build failed'; log: $RUN/logs/h29-bad-build.err"
  fi

  if ! grep -qF 'will close its open shells and Claude sessions' "$RUN/logs/h29-bad-build.out"; then
    add_problem "the running sandbox got no warning before the build; log: $RUN/logs/h29-bad-build.out"
  fi

  if [ -z "$idBefore" ] || [ "$(sandbox_field '{{.Id}}')" != "$idBefore" ]; then
    add_problem "the failed build changed the container id"
  fi

  if [ -z "$startBefore" ] || [ "$(sandbox_field '{{.State.StartedAt}}')" != "$startBefore" ]; then
    add_problem "the failed build changed the start time of the container"
  fi

  if [ "$(sandbox_field '{{.State.Running}}')" != "true" ]; then
    add_problem "$CONTAINER is not running after the failed build"
  fi
}

# ------------------------------------------------------------------------------
# Writes a sentinel in three folders and records the volumes and other sandboxes
# ------------------------------------------------------------------------------
plant_and_snapshot() {
  mkdir -p "$sbxDir/state/claude"
  printf '%s\n' "$sentinelText" >"$sbxDir/hosttest/h29-sentinel.txt"
  printf '%s\n' "$sentinelText" >"$sbxDir/state/h29-sentinel.txt"
  printf '%s\n' "$sentinelText" >"$sbxDir/state/claude/h29-sentinel.txt"
  volumesBefore=$(list_project_volumes)
  othersBefore=$(list_other_containers)
}

# ------------------------------------------------------------------------------
# Checks the one bind mount: the registered folder at the workspace
# ------------------------------------------------------------------------------
# The Source is compared by its last path component only, because Docker Desktop
# may show the folder under a different prefix.
# ------------------------------------------------------------------------------
check_one_bind_mount() {
  local mountLines mountCount sbxBase mountType mountDestination mountSource

  mountLines=$(docker container inspect \
    --format '{{range .Mounts}}{{.Type}} {{.Destination}} {{.Source}}{{println}}{{end}}' \
    "$CONTAINER" </dev/null 2>&1 | grep .)
  mountCount=$(printf '%s\n' "$mountLines" | grep -c .)
  sbxBase=$(basename "$sbxDir")

  if [ "$mountCount" -ne 1 ]; then
    add_problem "expected exactly one mount; got $mountCount: $(join_lines "$mountLines" ';')"
    return
  fi

  mountType=$(printf '%s\n' "$mountLines" | cut -d' ' -f1)
  mountDestination=$(printf '%s\n' "$mountLines" | cut -d' ' -f2)
  mountSource=$(printf '%s\n' "$mountLines" | cut -d' ' -f3-)

  if [ "$mountType" != "bind" ] || [ "$mountDestination" != "/home/sandbox/workspace" ]; then
    add_problem "expected a bind mount at /home/sandbox/workspace; got: $mountLines"
  fi

  case "$mountSource" in
    *"/$sbxBase")
      ;;
    *)
      add_problem "the mount Source does not end in $sbxBase; Source is: $mountSource"
      ;;
  esac
}

# ------------------------------------------------------------------------------
# Checks sbx-upgrade of a running sandbox: new container, same files and mount
# ------------------------------------------------------------------------------
check_upgrade() {
  local sentinelFile
  local volumesAfter
  local lastLine

  run_sbx h29-upgrade sbx-upgrade hosttest

  if [ "$sbxStatus" -ne 0 ]; then
    add_problem "sbx-upgrade exited $sbxStatus; log: $RUN/logs/h29-upgrade.err"
  fi

  if ! grep -qF 'will close its open shells and Claude sessions' "$RUN/logs/h29-upgrade.out"; then
    add_problem "the running sandbox got no warning before the upgrade; log: $RUN/logs/h29-upgrade.out"
  fi

  if [ -z "$idBefore" ] || [ "$(sandbox_field '{{.Id}}')" = "$idBefore" ]; then
    add_problem "sbx-upgrade did not recreate the container"
  fi

  if [ "$(sandbox_field '{{.State.Running}}')" != "true" ]; then
    add_problem "$CONTAINER is not running after sbx-upgrade"
  fi

  if ! docker exec "$CONTAINER" pgrep -x sleep >/dev/null 2>&1 </dev/null; then
    add_problem "the start hooks of $CONTAINER are not done after sbx-upgrade returned"
  fi

  for sentinelFile in "$sbxDir/hosttest/h29-sentinel.txt" "$sbxDir/state/h29-sentinel.txt" "$sbxDir/state/claude/h29-sentinel.txt"; do
    if [ "$(cat "$sentinelFile" 2>/dev/null)" != "$sentinelText" ]; then
      add_problem "$sentinelFile is missing or changed after sbx-upgrade"
    fi
  done

  volumesAfter=$(list_project_volumes)

  if [ "$volumesBefore" != "$volumesAfter" ]; then
    add_problem "the volume list changed during sbx-upgrade"
    add_problem "before: $(join_lines "$volumesBefore")"
    add_problem "after:  $(join_lines "$volumesAfter")"
  fi

  if [ "$othersBefore" != "$(list_other_containers)" ]; then
    add_problem "another sbx- container changed during sbx-upgrade"
    add_problem "before: $(join_lines "$othersBefore" ';')"
    add_problem "after:  $(join_lines "$(list_other_containers)" ';')"
  fi

  check_one_bind_mount

  lastLine=$(tail -n 1 "$RUN/logs/h29-upgrade.out")

  if [ "$lastLine" != "sbx-upgrade: sbx-hosttest runs on the new images" ]; then
    add_problem "the last line of sbx-upgrade is '$lastLine'; log: $RUN/logs/h29-upgrade.out"
  fi
}

# ------------------------------------------------------------------------------
# Checks that sbx-upgrade starts a stopped sandbox, with no warning
# ------------------------------------------------------------------------------
check_upgrade_of_stopped() {
  run_sbx h29-stop sbx-stop hosttest

  if [ "$sbxStatus" -ne 0 ]; then
    add_problem "sbx-stop exited $sbxStatus; log: $RUN/logs/h29-stop.err"
  fi

  run_sbx h29-upgrade-stopped sbx-upgrade hosttest

  if [ "$sbxStatus" -ne 0 ]; then
    add_problem "sbx-upgrade of a stopped sandbox exited $sbxStatus; log: $RUN/logs/h29-upgrade-stopped.err"
  fi

  if [ "$(sandbox_field '{{.State.Running}}')" != "true" ]; then
    add_problem "$CONTAINER is not running after sbx-upgrade of a stopped sandbox"
  fi

  if grep -qF 'will close its open shells and Claude sessions' "$RUN/logs/h29-upgrade-stopped.out"; then
    add_problem "a stopped sandbox got the open-shells warning; log: $RUN/logs/h29-upgrade-stopped.out"
  fi
}

# ------------------------------------------------------------------------------
# Main / Entry Point
# ------------------------------------------------------------------------------
require_no_arguments "$@" || exit 2
require_test_sandbox H-29 || exit 1
sbx_test_setup H-29 h29 || exit 1
prepare || exit 1
check_failed_build
plant_and_snapshot
check_upgrade
check_upgrade_of_stopped
restore_test_sandbox h29
report_check H-29 "sbx-upgrade did not rebuild and recreate the sandbox safely" \
  "a failed build left the sandbox as it was; sbx-upgrade rebuilt, recreated only sbx-hosttest, kept its files and one bind mount, and started a stopped sandbox"
