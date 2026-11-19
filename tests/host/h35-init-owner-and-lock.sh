#!/usr/bin/env bash
# ------------------------------------------------------------------------------
# H-35: sbx-init gives root-owned state back and refuses a second run
# ------------------------------------------------------------------------------
# Needs: test sandbox running; runs after H-34
# One throwaway root container makes a root-owned file in the test sandbox's
# state directory. A process in the test sandbox holds the run lock, so a second
# sbx-init is refused. The file is the test's own; it stays in the run directory.
# ------------------------------------------------------------------------------
set -u
. "$(dirname "$0")/lib.sh"
host_init

lockFile=/home/sandbox/.sbx-init.lock
markerFile=/home/sandbox/.sbx-init-done
plantedFile=/home/sandbox/workspace/state/claude/h35-root-owned-$$
holderName=h35-lock-holder
expectedLastLine="sbx-init: 4 steps passed; run sbx-selfcheck to check the sandbox"

# ------------------------------------------------------------------------------
# Makes a root-owned file in state/claude through a throwaway root container
# ------------------------------------------------------------------------------
# The container shares the test sandbox's volumes, runs offline and is removed.
# Returns 1 when the file is not root-owned afterwards.
# ------------------------------------------------------------------------------
plant_root_owned_file() {
  local plantOutput plantedOwner

  if ! plantOutput=$(run_timeout 120 docker run --rm --network none -u root --volumes-from "$CONTAINER" "$BASE_IMAGE" \
    sh -c 'touch "$1" && chown 0:0 "$1"' sh "$plantedFile" </dev/null 2>&1); then
    add_problem "the root container could not make $plantedFile: $(first_lines "$plantOutput")"
    return 1
  fi

  plantedOwner=$(docker exec "$CONTAINER" stat -c %u "$plantedFile" 2>/dev/null </dev/null)

  if [ "$plantedOwner" != "0" ]; then
    add_problem "the plant did not take: $plantedFile is owned by '$plantedOwner', not 0"
    return 1
  fi
}

# ------------------------------------------------------------------------------
# lock_is_held: succeeds when something holds the run lock in the test sandbox
# ------------------------------------------------------------------------------
# flock(1) and Python's fcntl.flock both use flock(2), so flock -n fails while
# another process holds the lock.
# ------------------------------------------------------------------------------
lock_is_held() {
  if docker exec "$CONTAINER" flock -n "$lockFile" true </dev/null >/dev/null 2>&1; then
    return 1
  fi

  return 0
}

# ------------------------------------------------------------------------------
# wait_for_lock held|free: polls at most 10 s; returns 1 when it never happened
# ------------------------------------------------------------------------------
wait_for_lock() {
  local wantedState=$1
  local waited=0

  while [ "$waited" -lt 10 ]; do
    if [ "$wantedState" = "held" ] && lock_is_held; then
      return 0
    fi

    if [ "$wantedState" = "free" ] && ! lock_is_held; then
      return 0
    fi

    sleep 1
    waited=$((waited + 1))
  done

  return 1
}

# ------------------------------------------------------------------------------
# Starts one process that holds the run lock; killing it releases the lock
# ------------------------------------------------------------------------------
# It sleeps at most 120 s on its own. Returns 1 when the lock is never held.
# ------------------------------------------------------------------------------
hold_lock() {
  if ! docker exec -d "$CONTAINER" python3 -c 'import fcntl, sys, time; handle = open(sys.argv[1], "a+"); fcntl.flock(handle, fcntl.LOCK_EX); time.sleep(120)' \
    "$lockFile" "$holderName" </dev/null >/dev/null 2>&1; then
    add_problem "could not start the lock holder in $CONTAINER"
    return 1
  fi

  if ! wait_for_lock held; then
    add_problem "the lock holder never took $lockFile within 10 s"
    return 1
  fi
}

# ------------------------------------------------------------------------------
# Checks a second sbx-init is refused and changes nothing
# ------------------------------------------------------------------------------
check_lock_refuses() {
  local lockedFile=$RUN/logs/h35-locked.out
  local lockedStatus plantedOwner

  run_timeout 120 docker exec "$CONTAINER" sbx-init >"$lockedFile" 2>&1 </dev/null
  lockedStatus=$?

  if [ "$lockedStatus" -ne 1 ]; then
    add_problem "sbx-init exited $lockedStatus while the lock was held; expected 1; output: $lockedFile"
  fi

  if ! grep -Fxq "FAIL: lock: another sbx-init is running" "$lockedFile" 2>/dev/null; then
    add_problem "sbx-init did not print 'FAIL: lock: another sbx-init is running'; output: $(first_lines "$(cat "$lockedFile" 2>/dev/null)")"
  fi

  if [ "$(tail -n 1 "$lockedFile" 2>/dev/null)" != "sbx-init: stopped at lock" ]; then
    add_problem "the last line of the refused sbx-init is not 'sbx-init: stopped at lock'; output: $lockedFile"
  fi

  if ! docker exec "$CONTAINER" test -e "$markerFile" </dev/null >/dev/null 2>&1; then
    add_problem "the refused sbx-init removed the marker $markerFile; it must change nothing"
  fi

  plantedOwner=$(docker exec "$CONTAINER" stat -c %u "$plantedFile" 2>/dev/null </dev/null)

  if [ "$plantedOwner" != "0" ]; then
    add_problem "the refused sbx-init changed the owner of $plantedFile to '$plantedOwner'; it must change nothing"
  fi
}

# ------------------------------------------------------------------------------
# Stops the lock holder and waits until the lock is free
# ------------------------------------------------------------------------------
# Runs on every path, so a failed check never leaves a holder behind.
# ------------------------------------------------------------------------------
release_lock() {
  docker exec "$CONTAINER" pkill -f "$holderName" </dev/null >/dev/null 2>&1

  if ! wait_for_lock free; then
    add_problem "the lock $lockFile is still held 10 s after the holder was stopped"
  fi
}

# ------------------------------------------------------------------------------
# Checks sbx-init gives the root-owned file back and leaves no root-owned state
# ------------------------------------------------------------------------------
check_owner_given_back() {
  local initFile=$RUN/logs/h35-init.out
  local initStatus plantedOwner rootOwnedList

  run_timeout 600 docker exec "$CONTAINER" sbx-init >"$initFile" 2>&1 </dev/null
  initStatus=$?

  if [ "$initStatus" -ne 0 ]; then
    add_problem "sbx-init exited $initStatus; expected 0; output: $initFile"
  fi

  if [ "$(tail -n 1 "$initFile" 2>/dev/null)" != "$expectedLastLine" ]; then
    add_problem "the last sbx-init line is not '$expectedLastLine'; output: $initFile"
  fi

  plantedOwner=$(docker exec "$CONTAINER" stat -c %u "$plantedFile" 2>/dev/null </dev/null)

  if [ "$plantedOwner" != "1000" ]; then
    add_problem "$plantedFile is owned by '$plantedOwner' after sbx-init; expected 1000"
  fi

  rootOwnedList=$(docker exec "$CONTAINER" find /home/sandbox/workspace/state -user 0 \
    -not -path '*/state/cache/npm*' -not -path '*/state/cache/uv*' -not -path '*/state/m2*' </dev/null 2>/dev/null)

  if [ -n "$rootOwnedList" ]; then
    add_problem "paths under state/ are still owned by root after sbx-init: $(first_lines "$rootOwnedList" 5)"
  fi

  info "H-35 $(grep -m 1 '^OK: state-owner:' "$initFile" 2>/dev/null)"
}

# ------------------------------------------------------------------------------
# Main / Entry Point
# ------------------------------------------------------------------------------
require_no_arguments "$@" || exit 2
require_test_sandbox H-35 || exit 1

if plant_root_owned_file; then
  if hold_lock; then
    check_lock_refuses
  fi
fi

release_lock
check_owner_given_back
report_check H-35 "sbx-init did not give root-owned state back or did not refuse a second run" \
  "sbx-init gave a root-owned file back to the sandbox user and left no root-owned state outside the caches; a second sbx-init was refused while one held the lock and changed nothing"
