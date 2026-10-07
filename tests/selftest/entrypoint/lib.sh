#!/usr/bin/env bash
# Shared by the entrypoint self-test groups: where the start scripts are and how a group starts.
# - Sourced by the groups, never run directly.
# - Defines functions only.

. "$(dirname "${BASH_SOURCE[0]}")/../lib-expect.sh"

# --------------------------------------------------------------------------------
# start_group: enters the repository root, sets ENTRY and START_LIB, and makes the work folder; returns 1 on failure.
# --------------------------------------------------------------------------------
start_group() {
  enter_repo_root || return 1

  ENTRY=$REPO/base/sbx-entrypoint
  START_LIB=$REPO/base/sbx-start-lib.sh

  make_work_folder entrytest || return 1
}
