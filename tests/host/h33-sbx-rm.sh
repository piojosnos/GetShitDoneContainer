#!/usr/bin/env bash
# ------------------------------------------------------------------------------
# H-33: sbx-rm removes the container, keeps every file; sbx-add brings it back
# ------------------------------------------------------------------------------
# Needs: test sandbox running; takes it down and restores it
# A real compose down on a folder with a space, then sbx-add of the same folder
# after --unregister. The running sandbox is first refused without a terminal,
# then removed with --yes.
# ------------------------------------------------------------------------------
set -u
. "$(dirname "$0")/lib.sh"
host_init
. "$(dirname "$0")/lib-sbx.sh"

sentinelText="h33-$$-$(date +%s)"
sbxDir=""
sbxPath=""
sbxStatus=0
volumesBefore=""
volumesBeforeRead=no
othersBefore=""
othersBeforeRead=no
closingLine=""

# ------------------------------------------------------------------------------
# list_project_volumes: the volume names of the Compose project sbx-hosttest
# ------------------------------------------------------------------------------
# Docker's errors go to the listings log, never into the list, so a failed
# call can never be compared as a list. Its exit status is docker's.
# ------------------------------------------------------------------------------
list_project_volumes() {
  docker volume ls -q --filter label=com.docker.compose.project=sbx-hosttest </dev/null 2>>"$RUN/logs/h33-listings.err"
}

# ------------------------------------------------------------------------------
# list_other_containers: name, id and state of every sbx- container but ours
# ------------------------------------------------------------------------------
# Returns 1 when docker ps fails. The filter runs only on what docker printed,
# so grep finding no other container is not a failure.
# ------------------------------------------------------------------------------
list_other_containers() {
  local containerText

  containerText=$(docker ps -a --filter name=sbx- --format '{{.Names}} {{.ID}} {{.State}}' </dev/null 2>>"$RUN/logs/h33-listings.err") || return 1
  printf '%s\n' "$containerText" | grep -v '^sbx-hosttest ' | sort
}

# ------------------------------------------------------------------------------
# container_exists: true when Docker has the container of the test sandbox
# ------------------------------------------------------------------------------
container_exists() {
  docker container inspect "$CONTAINER" >/dev/null 2>&1 </dev/null
}

# ------------------------------------------------------------------------------
# network_exists: true when Docker has the Compose network of the test sandbox
# ------------------------------------------------------------------------------
network_exists() {
  docker network inspect sbx-hosttest_default >/dev/null 2>&1 </dev/null
}

# ------------------------------------------------------------------------------
# expect_exit_zero LOG_NAME COMMAND_TEXT: a problem unless the last run exited 0
# ------------------------------------------------------------------------------
expect_exit_zero() {
  if [ "$sbxStatus" -ne 0 ]; then
    add_problem "$2 exited $sbxStatus; log: $RUN/logs/$1.err"
  fi
}

# ------------------------------------------------------------------------------
# expect_closing_line LOG_NAME: the last output line says nothing was changed
# ------------------------------------------------------------------------------
expect_closing_line() {
  local lastLine

  lastLine=$(tail -n 1 "$RUN/logs/$1.out")

  if [ "$lastLine" != "$closingLine" ]; then
    add_problem "the last line of sbx-rm is '$lastLine'; expected '$closingLine'; log: $RUN/logs/$1.out"
  fi
}

# ------------------------------------------------------------------------------
# entry_is_registered: true when the registry entry is the two lines of sbxDir
# ------------------------------------------------------------------------------
entry_is_registered() {
  printf 'SBX_DIR=%s\nSBX_AGENT=claude\n' "$sbxDir" | cmp -s - "$SBX_CONFIG_DIR/sandboxes/hosttest"
}

# ------------------------------------------------------------------------------
# sentinels_intact STEP: the two files and the history line are as planted
# ------------------------------------------------------------------------------
sentinels_intact() {
  local sentinelFile

  for sentinelFile in "$sbxDir/hosttest/h33-sentinel.txt" "$sbxDir/state/claude/h33-sentinel.txt"; do
    if [ "$(cat "$sentinelFile" 2>/dev/null)" != "$sentinelText" ]; then
      add_problem "$sentinelFile is missing or changed $1"
    fi
  done

  if ! grep -qxF -- "$sentinelText" "$sbxDir/state/shell/bash_history" 2>/dev/null; then
    add_problem "the sentinel line is missing from state/shell/bash_history $1"
  fi
}

# ------------------------------------------------------------------------------
# Registers the test sandbox on its own folder and starts it by name
# ------------------------------------------------------------------------------
prepare() {
  if ! compose_down >"$RUN/logs/h33-down.log" 2>&1; then
    fail H-33 "compose down failed before the test; log: $RUN/logs/h33-down.log"
    return 1
  fi

  run_sbx h33-add sbx-add hosttest "$sbxDir"

  if [ "$sbxStatus" -ne 0 ]; then
    fail H-33 "sbx-add exited $sbxStatus; log: $RUN/logs/h33-add.err"
    restore_test_sandbox h33
    return 1
  fi

  run_sbx h33-start sbx-start hosttest

  if [ "$sbxStatus" -ne 0 ]; then
    fail H-33 "sbx-start exited $sbxStatus; log: $RUN/logs/h33-start.err"
    restore_test_sandbox h33
    return 1
  fi
}

# ------------------------------------------------------------------------------
# Checks that sbx-rm is found through PATH
# ------------------------------------------------------------------------------
# A lost exec bit or a broken shebang fails here.
# ------------------------------------------------------------------------------
check_lookup() {
  local found

  found=$(PATH="$sbxPath" command -v sbx-rm)

  if [ "$found" != "$REPO_DIR/bin/sbx-rm" ]; then
    add_problem "sbx-rm was not found through PATH as $REPO_DIR/bin/sbx-rm (got: ${found:-nothing})"
  fi
}

# ------------------------------------------------------------------------------
# Writes the sentinels and records the volumes and the other sandboxes
# ------------------------------------------------------------------------------
plant_and_snapshot() {
  mkdir -p "$sbxDir/state/claude" "$sbxDir/state/shell"
  printf '%s\n' "$sentinelText" >"$sbxDir/hosttest/h33-sentinel.txt"
  printf '%s\n' "$sentinelText" >"$sbxDir/state/claude/h33-sentinel.txt"
  printf '%s\n' "$sentinelText" >>"$sbxDir/state/shell/bash_history"

  if volumesBefore=$(list_project_volumes); then
    volumesBeforeRead=yes
  else
    add_problem "docker volume ls failed before sbx-rm, so the volumes cannot be compared; log: $RUN/logs/h33-listings.err"
  fi

  if othersBefore=$(list_other_containers); then
    othersBeforeRead=yes
  else
    add_problem "docker ps failed before sbx-rm, so the other sandboxes cannot be compared; log: $RUN/logs/h33-listings.err"
  fi

  closingLine="sbx-rm: the container sbx-hosttest is gone; nothing in $sbxDir was changed"

  if ! network_exists; then
    add_problem "the network sbx-hosttest_default does not exist while the sandbox runs; Compose names its network differently on this Mac"
  fi
}

# ------------------------------------------------------------------------------
# compare_volumes_after: the volume list is as before sbx-rm
# ------------------------------------------------------------------------------
# A failed docker volume ls is a problem of its own, never a list to compare.
# ------------------------------------------------------------------------------
compare_volumes_after() {
  local volumesAfter

  if ! volumesAfter=$(list_project_volumes); then
    add_problem "docker volume ls failed after sbx-rm, so the volumes cannot be compared; log: $RUN/logs/h33-listings.err"
    return
  fi

  if [ "$volumesBeforeRead" != "yes" ]; then
    return
  fi

  if [ "$volumesBefore" != "$volumesAfter" ]; then
    add_problem "the volume list changed during sbx-rm"
    add_problem "before: $(join_lines "$volumesBefore")"
    add_problem "after:  $(join_lines "$volumesAfter")"
  fi
}

# ------------------------------------------------------------------------------
# compare_others_after: the other sbx- containers are as before sbx-rm
# ------------------------------------------------------------------------------
# A failed docker ps is a problem of its own, never a list to compare.
# ------------------------------------------------------------------------------
compare_others_after() {
  local othersAfter

  if ! othersAfter=$(list_other_containers); then
    add_problem "docker ps failed after sbx-rm, so the other sandboxes cannot be compared; log: $RUN/logs/h33-listings.err"
    return
  fi

  if [ "$othersBeforeRead" != "yes" ]; then
    return
  fi

  if [ "$othersBefore" != "$othersAfter" ]; then
    add_problem "another sbx- container changed during sbx-rm"
    add_problem "before: $(join_lines "$othersBefore" ';')"
    add_problem "after:  $(join_lines "$othersAfter" ';')"
  fi
}

# ------------------------------------------------------------------------------
# Checks that the running sandbox is refused without a terminal and --yes
# ------------------------------------------------------------------------------
# run_sbx closes stdin, so sbx-rm has no terminal to ask on. The sandbox, its
# entry and its files must stay as they were.
# ------------------------------------------------------------------------------
check_refused_without_yes() {
  run_sbx h33-rm-noterm sbx-rm hosttest --unregister

  if [ "$sbxStatus" -ne 1 ]; then
    add_problem "sbx-rm of the running sandbox without a terminal or --yes exited $sbxStatus, not 1; log: $RUN/logs/h33-rm-noterm.err"
  fi

  if ! grep -qF -- 'add --yes' "$RUN/logs/h33-rm-noterm.err"; then
    add_problem "sbx-rm without a terminal did not name --yes; log: $RUN/logs/h33-rm-noterm.err"
  fi

  if [ "$(sandbox_field '{{.State.Running}}')" != "true" ]; then
    add_problem "$CONTAINER is not running after sbx-rm was refused"
  fi

  if ! entry_is_registered; then
    add_problem "the refused sbx-rm changed the registry entry $SBX_CONFIG_DIR/sandboxes/hosttest"
  fi

  sentinels_intact "after the refused sbx-rm"
}

# ------------------------------------------------------------------------------
# Checks sbx-rm --yes of the running sandbox: the container and network go
# ------------------------------------------------------------------------------
check_remove_running() {
  run_sbx h33-rm sbx-rm hosttest --yes
  expect_exit_zero h33-rm "sbx-rm --yes of the running sandbox"

  if ! grep -qF 'will close its open shells and Claude sessions' "$RUN/logs/h33-rm.out"; then
    add_problem "the running sandbox got no warning before the removal; log: $RUN/logs/h33-rm.out"
  fi

  expect_closing_line h33-rm

  if container_exists; then
    add_problem "$CONTAINER still exists after sbx-rm"
  fi

  if network_exists; then
    add_problem "the network sbx-hosttest_default still exists after sbx-rm"
  fi

  if ! entry_is_registered; then
    add_problem "sbx-rm without --unregister changed the registry entry $SBX_CONFIG_DIR/sandboxes/hosttest"
  fi

  sentinels_intact "after sbx-rm"

  if ! docker image inspect "$CLAUDE_IMAGE" >/dev/null 2>&1 </dev/null; then
    add_problem "the image $CLAUDE_IMAGE is gone after sbx-rm"
  fi

  if ! docker image inspect "$BASE_IMAGE" >/dev/null 2>&1 </dev/null; then
    add_problem "the image $BASE_IMAGE is gone after sbx-rm"
  fi

  compare_volumes_after
  compare_others_after
}

# ------------------------------------------------------------------------------
# Checks that a second sbx-rm, with no container left, succeeds the same way
# ------------------------------------------------------------------------------
check_remove_again() {
  run_sbx h33-rm-again sbx-rm hosttest
  expect_exit_zero h33-rm-again "sbx-rm with no container"
  expect_closing_line h33-rm-again
}

# ------------------------------------------------------------------------------
# Checks sbx-rm while the registered folder is moved away
# ------------------------------------------------------------------------------
# The folder goes back by mv in every case; the host tests delete no file.
# ------------------------------------------------------------------------------
check_moved_folder() {
  run_sbx h33-start-moved sbx-start hosttest
  expect_exit_zero h33-start-moved "sbx-start"

  run_sbx h33-stop-moved sbx-stop hosttest
  expect_exit_zero h33-stop-moved "sbx-stop"

  if ! mv "$sbxDir" "$sbxDir moved"; then
    add_problem "could not move $sbxDir away"
    return
  fi

  run_sbx h33-rm-moved sbx-rm hosttest
  expect_exit_zero h33-rm-moved "sbx-rm with the folder moved away"

  if container_exists; then
    add_problem "$CONTAINER still exists after sbx-rm with the folder moved away"
  fi

  if ! mv "$sbxDir moved" "$sbxDir"; then
    add_problem "could not move $sbxDir moved back to $sbxDir"
    return
  fi

  sentinels_intact "after sbx-rm with the folder moved away"
}

# ------------------------------------------------------------------------------
# Checks --unregister: the entry goes, the folder stays
# ------------------------------------------------------------------------------
check_unregister() {
  run_sbx h33-unregister sbx-rm hosttest --unregister
  expect_exit_zero h33-unregister "sbx-rm --unregister"

  if [ -e "$SBX_CONFIG_DIR/sandboxes/hosttest" ]; then
    add_problem "the registry entry still exists after sbx-rm --unregister"
  fi

  if ! grep -qF 'deleted the registry entry' "$RUN/logs/h33-unregister.out"; then
    add_problem "sbx-rm --unregister did not say it deleted the registry entry; log: $RUN/logs/h33-unregister.out"
  fi

  if [ ! -d "$sbxDir/hosttest" ] || [ ! -d "$sbxDir/state" ]; then
    add_problem "sbx-rm --unregister changed the sandbox folder $sbxDir"
  fi

  sentinels_intact "after sbx-rm --unregister"
}

# ------------------------------------------------------------------------------
# Checks that sbx-add of the same folder brings the login and history back
# ------------------------------------------------------------------------------
# state/claude and state/shell hold the login and the history, so a new
# container on the same folder finds both again.
# ------------------------------------------------------------------------------
check_add_again() {
  local historyText

  run_sbx h33-add-again sbx-add hosttest "$sbxDir"
  expect_exit_zero h33-add-again "sbx-add of the same folder"

  if ! entry_is_registered; then
    add_problem "sbx-add of the same folder did not write the same entry again"
  fi

  run_sbx h33-start-again sbx-start hosttest
  expect_exit_zero h33-start-again "sbx-start after sbx-add"

  if [ "$(in_container sh -c 'cat "$CLAUDE_CONFIG_DIR/h33-sentinel.txt"')" != "$sentinelText" ]; then
    add_problem "the file in \$CLAUDE_CONFIG_DIR did not come back in the new container"
  fi

  historyText=$(in_container sh -c 'cat "$HISTFILE"')

  if ! printf '%s\n' "$historyText" | grep -qxF -- "$sentinelText"; then
    add_problem "the line in \$HISTFILE did not come back in the new container"
  fi

  if [ "$(in_container cat /home/sandbox/workspace/hosttest/h33-sentinel.txt)" != "$sentinelText" ]; then
    add_problem "the file in the project folder did not come back in the new container"
  fi
}

# ------------------------------------------------------------------------------
# Main / Entry Point
# ------------------------------------------------------------------------------
require_no_arguments "$@" || exit 2
require_test_sandbox H-33 || exit 1
sbx_test_setup H-33 h33 || exit 1
prepare || exit 1
check_lookup
plant_and_snapshot
check_refused_without_yes
check_remove_running
check_remove_again
check_moved_folder
check_unregister
check_add_again
restore_test_sandbox h33
report_check H-33 "sbx-rm did not remove the sandbox safely, or sbx-add did not bring it back" \
  "sbx-rm without a terminal or --yes refused the running sandbox and kept it; with --yes it took the container and its network and kept the folder, the entry, the volumes, the images and the other sandboxes; it ran again with no container and with the folder moved; --unregister deleted only the entry; sbx-add of the same folder brought back state/claude and the history"
