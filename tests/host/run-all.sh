#!/usr/bin/env bash
# Host tests: runs every check that needs no human, then prints a summary.
# - Unattended. Needs no environment variables and never waits for input.
# - Builds sbx-base:local and sbx-claude:local (the real tags). Images are never removed.
# - Creates a throwaway sandbox named sbx-hosttest in a fresh temp folder. Real sandboxes
#   are never touched, whatever SBX_NAME, SBX_DIR or COMPOSE_* hold in your terminal.
# - Deletes nothing. At the end, pass or fail, it prints the manual pass commands and the
#   cleanup command for you to run.
# - SBXTEST_NO_CACHE=1 (optional) makes the rebuild check rebuild without the cache; slow.
# - Usage, from anywhere: bash tests/host/run-all.sh   (exit 0 = every check passed)
set -u
. "$(dirname "$0")/lib.sh"
host_init
RUN=""
unset SBXTEST_DIR

trap 'exit 130' INT TERM
trap print_next_block EXIT

# Check lists, in run order. Each check names what it needs in its "# Depends on:" line.
# - Checks that need nothing from the sandbox come first.
# - Then the checks on the running sandbox; a failure does not stop the others.
# - Then the chain of checks that stop and restart the sandbox; it stops at its first failure.
# - Then Coexistence, which compares against the state at the start of the run.
noSandboxCheckList=""
sandboxCheckList="h04-nonroot-user.sh"
chainCheckList=""
finalCheckList=""

remainingList="$noSandboxCheckList $sandboxCheckList $chainCheckList $finalCheckList"
passedCount=0
failedCount=0
notRunCount=0
failedList=""

# drop_remaining SCRIPT: SCRIPT has been run or marked, so it is no longer waiting.
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

# run_check SCRIPT: runs one check as a child process and counts it by exit status.
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

# run_list SCRIPT...: runs every check, even after a failure.
run_list() {
  local script

  for script in $1; do
    run_check "$script"
  done
}

# mark_not_run SCRIPT... REASON: prints and counts the checks that did not run.
mark_not_run() {
  local script

  for script in $1; do
    printf 'NOT RUN: %s (%s)\n' "$script" "$2"
    notRunCount=$((notRunCount + 1))
    drop_remaining "$script"
  done
}

# run_chain SCRIPT...: runs the checks in order; after the first failure the rest are not run.
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

# record_setup_failure TEXT: counts a failure that belongs to no check.
record_setup_failure() {
  printf 'FAIL: SETUP %s\n' "$1"
  failedCount=$((failedCount + 1))
  failedList="$failedList SETUP"
}

# finish REASON: marks what is left as not run, prints the summary, exits 0 or 1.
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

# fatal TEXT: a setup step failed, so nothing else can run.
fatal() {
  record_setup_failure "$1"
  finish "setup failed"
}

if ! docker info >/dev/null 2>&1 </dev/null; then
  fatal "the Docker daemon is not reachable; start Docker Desktop and run again"
fi

if ! make_run_dir; then
  fatal "could not create the run folder"
fi
info "run folder: $RUN"

snapshot_old_containers >"$RUN/logs/old-containers.before"

if ! remove_leftover_test_container; then
  fatal "an earlier sbx-hosttest container is in the way and was not removed (see the messages above)"
fi

info "building the images (logs in $RUN/logs)"
if ! build_images build; then
  fatal "the image build failed"
fi

run_list "$noSandboxCheckList"

if compose_up; then
  run_list "$sandboxCheckList"
  run_chain "$chainCheckList"
else
  record_setup_failure "the test sandbox did not start (log: $RUN/logs/compose-up.log)"
  mark_not_run "$sandboxCheckList $chainCheckList" "the test sandbox did not start"
fi

run_list "$finalCheckList"

finish "not reached"
