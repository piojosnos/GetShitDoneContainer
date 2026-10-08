#!/usr/bin/env bash
# Host tests: runs every check that needs no human, then prints a summary.
# - Unattended. Needs no environment variables and never waits for input.
# - Builds sbx-base:local and sbx-claude:local (the real tags). Images are never removed.
# - Creates a throwaway sandbox named sbx-hosttest in a fresh temp folder. Real sandboxes
#   are never touched, whatever SBX_NAME, SBX_DIR or COMPOSE_* hold in your terminal.
# - Uses the Docker your terminal points at (DOCKER_HOST or the current Docker context) and
#   prints which one first.
# - Deletes nothing. At the end, pass or fail, it prints the cleanup command for you to run
#   and where the diagnostic helpers are.
# - SBXTEST_NO_CACHE=1 (optional) makes the rebuild check rebuild without the cache; slow.
# - Usage, from anywhere: bash tests/host/run-all.sh   (exit 0 = every check passed)
set -u
. "$(dirname "$0")/lib.sh"
host_init
RUN=""
unset SBXTEST_DIR

# --------------------------------------------------------------------------------
# Check lists, in run order. Each check names what it needs in its "# Depends on:" line.
# --------------------------------------------------------------------------------
# - The Compose check is fatal: without Compose v2 nothing else can run.
# - Checks that need nothing from the sandbox come first.
# - Then the checks on the running sandbox; a failure does not stop the others.
# - Then the chain of checks that stop and restart the sandbox; it stops at its first failure.
#   H-10 is last because it is the most likely to fail for an environmental reason (Compose may
#   create a missing folder), and it leaves the sandbox up either way.
# - Then Coexistence, which compares against the state at the start of the run.
fatalCheck="h00-compose-v2.sh"
noSandboxCheckList="h02-claude-on-base.sh h03-variable-interpolation.sh h12-plain-run-refused-pin-installed.sh h17-start-offline-and-failing-hook.sh h21-bad-name-refused.sh"
sandboxCheckList="h01-native-arch.sh h04-nonroot-user.sh h05-workspace-and-home.sh h06-git-and-identity.sh h13-env-and-no-self-update.sh h14-bundle-in-image.sh h15-bundle-synced-and-visible.sh h18-scope-and-deny.sh"
chainCheckList="h08-history-survives-recreate.sh h16-sync-refreshes-and-spares.sh h11-stop-is-quick-and-safe.sh h09-rebuild-keeps-files-no-volumes.sh h20-mistyped-name-refused.sh h10-missing-folder-refused.sh"
finalCheckList="coexistence.sh"

remainingList="$fatalCheck $noSandboxCheckList $sandboxCheckList $chainCheckList $finalCheckList"
passedCount=0
failedCount=0
notRunCount=0
failedList=""

# --------------------------------------------------------------------------------
# drop_remaining SCRIPT: SCRIPT has been run or marked, so it is no longer waiting.
# --------------------------------------------------------------------------------
drop_remaining() {
  local script item
  local keptList=""

  script=$1

  for item in $remainingList; do
    if [ "$item" != "$script" ]; then
      keptList="$keptList $item"
    fi
  done
  remainingList=$keptList
}

# --------------------------------------------------------------------------------
# run_check SCRIPT: runs one check as a child process and counts it by exit status.
# --------------------------------------------------------------------------------
run_check() {
  local script=$1

  drop_remaining "$script"

  if bash "$HOST_DIR/$script" </dev/null; then
    passedCount=$((passedCount + 1))
    return 0
  fi

  failedCount=$((failedCount + 1))
  failedList="$failedList $script"

  return 1
}

# --------------------------------------------------------------------------------
# run_list SCRIPT...: runs every check, even after a failure.
# --------------------------------------------------------------------------------
run_list() {
  local script

  for script in $1; do
    run_check "$script"
  done
}

# --------------------------------------------------------------------------------
# mark_not_run SCRIPT... REASON: prints and counts the checks that did not run.
# --------------------------------------------------------------------------------
mark_not_run() {
  local script

  for script in $1; do
    printf 'NOT RUN: %s (%s)\n' "$script" "$2"
    notRunCount=$((notRunCount + 1))
    drop_remaining "$script"
  done
}

# --------------------------------------------------------------------------------
# run_chain SCRIPT...: runs the checks in order; after the first failure the rest are not run.
# --------------------------------------------------------------------------------
run_chain() {
  local script
  local stopped=0

  for script in $1; do
    if [ "$stopped" -eq 1 ]; then
      mark_not_run "$script" "an earlier check in the chain failed"
    elif ! run_check "$script"; then
      stopped=1
    fi
  done
}

# --------------------------------------------------------------------------------
# record_setup_failure TEXT: counts a failure that belongs to no check.
# --------------------------------------------------------------------------------
record_setup_failure() {
  printf 'FAIL: SETUP %s\n' "$1"
  failedCount=$((failedCount + 1))
  failedList="$failedList SETUP"
}

# --------------------------------------------------------------------------------
# finish REASON: marks what is left as not run, prints the summary, exits 0 or 1.
# --------------------------------------------------------------------------------
finish() {
  mark_not_run "$remainingList" "$1"
  printf '\nSummary: %s passed, %s failed, %s not run\n' "$passedCount" "$failedCount" "$notRunCount"

  if [ -n "$failedList" ]; then
    printf 'Failed:%s\n' "$failedList"
  fi

  if [ "$failedCount" -eq 0 ] && [ "$notRunCount" -eq 0 ]; then
    exit 0
  fi
  exit 1
}

# --------------------------------------------------------------------------------
# fatal TEXT: a setup step failed, so nothing else can run.
# --------------------------------------------------------------------------------
fatal() {
  record_setup_failure "$1"
  finish "setup failed"
}

# --------------------------------------------------------------------------------
# print_next_block: prints the cleanup command and where the diagnostic helpers are. Only prints.
# --------------------------------------------------------------------------------
print_next_block() {
  printf '\nNext\n'

  if [ -n "${RUN:-}" ]; then
    printf '  Cleanup when you are done. The run folder holds a Claude login if a helper logged in:\n'
    printf '    cd %q && SBX_NAME=hosttest SBX_DIR=%q docker compose down && rm -rf %q\n' "${REPO_DIR:-}" "$RUN" "$RUN"
  else
    printf '  No run folder was created, so there is nothing to clean up.\n'
  fi

  printf '  If something looks wrong, see tests/host/manual/\n'
}

# --------------------------------------------------------------------------------
# install_traps: Ctrl-C exits 130; the Next block prints whenever the run ends.
# --------------------------------------------------------------------------------
install_traps() {
  trap 'exit 130' INT TERM
  trap print_next_block EXIT
}

# --------------------------------------------------------------------------------
# print_docker_target: prints the Docker context and DOCKER_HOST this run talks to.
# --------------------------------------------------------------------------------
print_docker_target() {
  local contextName

  if ! contextName=$(docker context show 2>/dev/null </dev/null) || [ -z "$contextName" ]; then
    contextName=unknown
  fi

  info "docker context: $contextName, DOCKER_HOST: ${DOCKER_HOST:-not set}"
}

# --------------------------------------------------------------------------------
# check_docker_reachable: stops the run when the Docker daemon does not answer.
# --------------------------------------------------------------------------------
check_docker_reachable() {
  if ! docker info >/dev/null 2>&1 </dev/null; then
    fatal "the Docker daemon is not reachable; start Docker Desktop and run again"
  fi
}

# --------------------------------------------------------------------------------
# create_run_folder: makes the run folder and prints its path; stops the run when it cannot.
# --------------------------------------------------------------------------------
create_run_folder() {
  if ! make_run_dir; then
    fatal "could not create the run folder"
  fi

  info "run folder: $RUN"
}

# --------------------------------------------------------------------------------
# record_old_layout: writes the old containers and the old folders to the run folder's logs, for Coexistence to compare at the end.
# --------------------------------------------------------------------------------
# Each snapshot is captured first and written after, so a failed one never leaves a partial baseline.
record_old_layout() {
  local containerSnapshot folderSnapshot

  if ! containerSnapshot=$(snapshot_old_containers); then
    fatal "docker ps failed; the old containers cannot be recorded"
  fi

  printf '%s\n' "$containerSnapshot" >"$RUN/logs/old-containers.before"

  if folderSnapshot=$(snapshot_old_folders); then
    printf '%s\n' "$folderSnapshot" >"$RUN/logs/old-folders.before"
  else
    info "git could not read ClaudeCode/ and OpenCode/; Coexistence will report it"
  fi
}

# --------------------------------------------------------------------------------
# remove_leftover_test_container: takes down an earlier test container; stops the run if the name is taken by something else or the take down fails.
# --------------------------------------------------------------------------------
remove_leftover_test_container() {
  local label

  if ! docker container inspect "$CONTAINER" >/dev/null 2>&1 </dev/null; then
    return 0
  fi

  label=$(docker container inspect --format '{{index .Config.Labels "sbx.name"}}' "$CONTAINER" 2>/dev/null </dev/null)
  if [ "$label" != "hosttest" ]; then
    printf 'A container named %s exists but is not labelled sbx.name=hosttest. It was left alone.\n' "$CONTAINER" >&2
    fatal "an earlier sbx-hosttest container is in the way and was not removed (see the messages above)"
  fi

  if ! compose_down >"$RUN/logs/leftover-down.log" 2>&1; then
    fatal "an earlier sbx-hosttest container is in the way and was not removed (see the messages above)"
  fi

  return 0
}

# --------------------------------------------------------------------------------
# run_compose_check: runs the Compose check; the run ends here when it fails.
# --------------------------------------------------------------------------------
run_compose_check() {
  if ! run_check "$fatalCheck"; then
    finish "the Compose check failed"
  fi
}

# --------------------------------------------------------------------------------
# build_all_images: builds both images; stops the run when the build fails.
# --------------------------------------------------------------------------------
build_all_images() {
  info "building the images (logs in $RUN/logs)"

  if ! build_images build; then
    fatal "the image build failed"
  fi
}

# --------------------------------------------------------------------------------
# run_sandbox_checks: starts the test sandbox, then runs the checks on it and the chain; marks them not run when it does not start.
# --------------------------------------------------------------------------------
run_sandbox_checks() {
  if compose_up; then
    run_list "$sandboxCheckList"
    run_chain "$chainCheckList"
  else
    record_setup_failure "the test sandbox did not start (log: $RUN/logs/compose-up.log)"
    mark_not_run "$sandboxCheckList $chainCheckList" "the test sandbox did not start"
  fi
}

# --------------------------------------------------------------------------------
# Main / Entry Point
# --------------------------------------------------------------------------------
require_no_arguments "$@" || exit 2
install_traps
print_docker_target
check_docker_reachable
create_run_folder
record_old_layout
remove_leftover_test_container
run_compose_check
build_all_images
run_list "$noSandboxCheckList"
run_sandbox_checks
run_list "$finalCheckList"
finish "not reached"
