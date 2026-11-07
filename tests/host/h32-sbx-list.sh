#!/usr/bin/env bash
# ------------------------------------------------------------------------------
# H-32: sbx-list shows each sandbox with the status docker ps -a shows
# ------------------------------------------------------------------------------
# Needs: test sandbox running; takes it down and restores it
# Only the hosttest lines are read: the Mac also has the user's own sandboxes.
# ------------------------------------------------------------------------------
set -u
. "$(dirname "$0")/lib.sh"
host_init
. "$(dirname "$0")/lib-sbx.sh"

sbxDir=""
sbxPath=""
sbxStatus=0

# ------------------------------------------------------------------------------
# docker_state: prints the State docker ps -a shows for the test container
# ------------------------------------------------------------------------------
# Prints nothing when Docker has no such container.
# ------------------------------------------------------------------------------
docker_state() {
  docker ps -a --format '{{.Names}} {{.State}}' 2>/dev/null </dev/null | awk -v containerName="$CONTAINER" '$1 == containerName { print $2; exit }'
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
# expect_row LOG_NAME STATUS: the list has the hosttest row with STATUS
# ------------------------------------------------------------------------------
expect_row() {
  local expectedRow
  local dockerState

  expectedRow=$(printf '%-31s %-20s %s' hosttest "$2" "$sbxDir")
  dockerState=$(docker_state)

  if ! grep -qxF -- "$expectedRow" "$RUN/logs/$1.out"; then
    add_problem "sbx-list did not show hosttest as $2 with its folder; docker ps -a shows: ${dockerState:-no container}; log: $RUN/logs/$1.out"
  fi
}

# ------------------------------------------------------------------------------
# expect_docker_state STATE: docker ps -a shows STATE (empty: no container)
# ------------------------------------------------------------------------------
expect_docker_state() {
  local dockerState

  dockerState=$(docker_state)

  if [ "$dockerState" != "$1" ]; then
    add_problem "docker ps -a shows ${dockerState:-no container} for $CONTAINER, not ${1:-no container}"
  fi
}

# ------------------------------------------------------------------------------
# Checks that sbx-list is found through PATH
# ------------------------------------------------------------------------------
# A lost exec bit or a broken shebang fails here.
# ------------------------------------------------------------------------------
check_lookup() {
  local found

  found=$(PATH="$sbxPath" command -v sbx-list)

  if [ "$found" != "$REPO_DIR/bin/sbx-list" ]; then
    add_problem "sbx-list was not found through PATH as $REPO_DIR/bin/sbx-list (got: ${found:-nothing})"
  fi
}

# ------------------------------------------------------------------------------
# Checks the empty registry: the running test container is listed as unknown
# ------------------------------------------------------------------------------
# The test registry is still empty here. The old cc_ containers must not show.
# ------------------------------------------------------------------------------
check_unregistered() {
  local leftoverLine

  run_sbx h32-list-before sbx-list
  expect_exit_zero h32-list-before "sbx-list with an empty registry"

  if ! grep -qF 'no sandboxes registered' "$RUN/logs/h32-list-before.out"; then
    add_problem "sbx-list with an empty registry did not say no sandboxes are registered; log: $RUN/logs/h32-list-before.out"
  fi

  leftoverLine=$(printf '  %-35s %s' "$CONTAINER" running)

  if ! grep -qxF -- "$leftoverLine" "$RUN/logs/h32-list-before.out"; then
    add_problem "sbx-list did not list $CONTAINER as running without a registry entry; log: $RUN/logs/h32-list-before.out"
  fi

  if grep -q 'cc_' "$RUN/logs/h32-list-before.out"; then
    add_problem "sbx-list printed a line with cc_: an old-layout container is listed; log: $RUN/logs/h32-list-before.out"
  fi

  expect_docker_state running
}

# ------------------------------------------------------------------------------
# Takes the test sandbox down, then registers it on its own folder
# ------------------------------------------------------------------------------
take_sandbox_down() {
  if ! compose_down >"$RUN/logs/h32-down.log" 2>&1; then
    fail H-32 "compose down failed before the test; log: $RUN/logs/h32-down.log"
    return 1
  fi

  run_sbx h32-add sbx-add hosttest "$sbxDir"
  expect_exit_zero h32-add "sbx-add"
}

# ------------------------------------------------------------------------------
# Checks a registered sandbox that Docker has no container for
# ------------------------------------------------------------------------------
check_no_container() {
  run_sbx h32-list-none sbx-list
  expect_exit_zero h32-list-none "sbx-list of a sandbox with no container"
  expect_row h32-list-none 'no container'
  expect_docker_state ""
}

# ------------------------------------------------------------------------------
# Checks a running sandbox: running, and not marked as older
# ------------------------------------------------------------------------------
# The exact row proves there is no older image mark: a false mark here would
# mean sbx-list and sbx-start disagree on this Docker.
# ------------------------------------------------------------------------------
check_running() {
  local leftoverLine

  run_sbx h32-start sbx-start hosttest
  expect_exit_zero h32-start "sbx-start"

  run_sbx h32-list-running sbx-list
  expect_exit_zero h32-list-running "sbx-list of a running sandbox"
  expect_row h32-list-running running
  expect_docker_state running

  leftoverLine=$(printf '  %-35s %s' "$CONTAINER" running)

  if grep -qxF -- "$leftoverLine" "$RUN/logs/h32-list-running.out"; then
    add_problem "sbx-list listed $CONTAINER as having no registry entry, although hosttest is registered; log: $RUN/logs/h32-list-running.out"
  fi
}

# ------------------------------------------------------------------------------
# Checks a stopped sandbox: stopped here, exited in Docker
# ------------------------------------------------------------------------------
check_stopped() {
  run_sbx h32-stop sbx-stop hosttest
  expect_exit_zero h32-stop "sbx-stop"

  run_sbx h32-list-stopped sbx-list
  expect_exit_zero h32-list-stopped "sbx-list of a stopped sandbox"
  expect_row h32-list-stopped stopped
  expect_docker_state exited
}

# ------------------------------------------------------------------------------
# Main / Entry Point
# ------------------------------------------------------------------------------
require_no_arguments "$@" || exit 2
require_test_sandbox H-32 || exit 1
sbx_test_setup H-32 h32 || exit 1
check_lookup
check_unregistered
take_sandbox_down || exit 1
check_no_container
check_running
check_stopped
restore_test_sandbox h32
report_check H-32 "sbx-list did not match docker ps -a" \
  "sbx-list showed no container, running and stopped as docker ps -a did, with the folder that has a space; it marked no sandbox on the current image and listed the unregistered test container by its label, with no cc_ container"
