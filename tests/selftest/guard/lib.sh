#!/usr/bin/env bash
# ------------------------------------------------------------------------------
# Shared by the guard self-test groups: start a group, plant in a copy
# ------------------------------------------------------------------------------
# Usage: sourced by the groups, never run directly (functions only)
# Linux only, in the dev sandbox.
# ------------------------------------------------------------------------------

. "$(dirname "${BASH_SOURCE[0]}")/../lib-expect.sh"

# ------------------------------------------------------------------------------
# start_group: enters the repo root and makes the work folder (1 on failure)
# ------------------------------------------------------------------------------
start_group() {
  enter_repo_root || return 1
  make_work_folder guardtest || return 1
}

# ------------------------------------------------------------------------------
# make_scratch_repo: a fresh WORK/repo with the working tree, no .git
# ------------------------------------------------------------------------------
# A guard program run from the copy scans the copy, so a case can plant a
# problem without touching the real tree.
# ------------------------------------------------------------------------------
make_scratch_repo() {
  rm -rf "$WORK/repo"
  mkdir -p "$WORK/repo" || return 1

  tar -C "$REPO" --exclude=.git -cf - . | tar -C "$WORK/repo" -xf -

  [ -f "$WORK/repo/tests/guard/lib.sh" ]
}

# ------------------------------------------------------------------------------
# run_scratch_guard OUTFILE GROUP: runs a guard group from the scratch copy
# ------------------------------------------------------------------------------
# Stdin is closed and all output goes to OUTFILE; the exit status is GUARD_RC.
# ------------------------------------------------------------------------------
run_scratch_guard() {
  GUARD_RC=0
  bash "$WORK/repo/tests/guard/$2" >"$1" 2>&1 </dev/null || GUARD_RC=$?
}
