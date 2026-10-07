#!/usr/bin/env bash
# Shared by the guard self-test groups: how a group starts.
# - Sourced by the groups, never run directly; defines functions only.
# - Linux only, in the dev sandbox.

. "$(dirname "${BASH_SOURCE[0]}")/../lib-expect.sh"

# --------------------------------------------------------------------------------
# start_group: enters the repository root and makes the work folder; returns 1 on failure.
# --------------------------------------------------------------------------------
start_group() {
  enter_repo_root || return 1
  make_work_folder guardtest || return 1
}
