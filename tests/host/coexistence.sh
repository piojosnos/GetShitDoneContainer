#!/usr/bin/env bash
# ------------------------------------------------------------------------------
# Coexistence: old-layout containers and files are untouched by the run
# ------------------------------------------------------------------------------
# Needs: nothing
# Alone, with no start snapshots, it checks git only: ClaudeCode/ and OpenCode/.
# ------------------------------------------------------------------------------
set -u
. "$(dirname "$0")/lib.sh"
host_init

containerBaselineFile=""
folderBaselineFile=""
compared="git only; no baseline"

# ------------------------------------------------------------------------------
# Finds the snapshots run-all.sh took at the start of the run
# ------------------------------------------------------------------------------
# Dirt that was already there and did not change passes. Only reads; writes
# logs/old-containers.after and logs/old-folders.after in the run folder.
# ------------------------------------------------------------------------------
find_baselines() {
  if [ -n "$RUN" ] && [ -f "$RUN/logs/old-containers.before" ]; then
    containerBaselineFile="$RUN/logs/old-containers.before"
  fi

  if [ -n "$RUN" ] && [ -f "$RUN/logs/old-folders.before" ]; then
    folderBaselineFile="$RUN/logs/old-folders.before"
  fi

  if [ -n "$containerBaselineFile" ] && [ -n "$folderBaselineFile" ]; then
    compared="container and folder snapshots"
  elif [ -n "$containerBaselineFile" ]; then
    compared="container snapshot and git"
  elif [ -n "$folderBaselineFile" ]; then
    compared="folder snapshot and no container baseline"
  fi
}

# ------------------------------------------------------------------------------
# Compares the old container list now with the one from the start of the run
# ------------------------------------------------------------------------------
# A failed docker ps is a failure to read, never compared as an empty list.
# ------------------------------------------------------------------------------
check_old_containers_unchanged() {
  local beforeText afterText

  if [ -z "$containerBaselineFile" ]; then
    return
  fi

  if ! afterText=$(snapshot_old_containers); then
    add_problem "docker ps failed; the old containers could not be compared"
    return
  fi

  printf '%s\n' "$afterText" >"$RUN/logs/old-containers.after"
  beforeText=$(cat "$containerBaselineFile")

  if [ "$beforeText" != "$afterText" ]; then
    add_problem "the old containers changed during the run"
    add_problem "before: $(join_lines "$beforeText" ';')"
    add_problem "after:  $(join_lines "$afterText" ';')"
    add_problem "if you started or stopped a cc_ container during the run, re-run"
  fi
}

# ------------------------------------------------------------------------------
# Compares ClaudeCode/ and OpenCode/ with the snapshot from the start
# ------------------------------------------------------------------------------
# A failed git is a failure to read, never compared as changes.
# ------------------------------------------------------------------------------
check_old_folders_unchanged() {
  local beforeText afterText

  if [ -z "$folderBaselineFile" ]; then
    check_old_folders_clean
    return
  fi

  if ! afterText=$(snapshot_old_folders); then
    add_problem "git could not read ClaudeCode/ and OpenCode/"
    return
  fi

  printf '%s\n' "$afterText" >"$RUN/logs/old-folders.after"
  beforeText=$(cat "$folderBaselineFile")

  if [ "$beforeText" != "$afterText" ]; then
    add_problem "the old folders changed during the run"
    add_problem "before: $(join_lines "$beforeText" ';')"
    add_problem "after:  $(join_lines "$afterText" ';')"
  fi
}

# ------------------------------------------------------------------------------
# Checks git shows no change under ClaudeCode/ or OpenCode/
# ------------------------------------------------------------------------------
# Used when there is no snapshot from the start to compare with.
# ------------------------------------------------------------------------------
check_old_folders_clean() {
  local gitOutput

  if ! gitOutput=$(git -C "$REPO_DIR" status --porcelain --untracked-files=all -- ClaudeCode OpenCode 2>&1 </dev/null); then
    add_problem "git could not read ClaudeCode/ and OpenCode/: $(first_lines "$gitOutput")"
    return
  fi

  if [ -n "$gitOutput" ]; then
    add_problem "git status shows changes under ClaudeCode/ or OpenCode/: $(join_lines "$gitOutput" ';')"
  fi
}

# ------------------------------------------------------------------------------
# Main / Entry Point
# ------------------------------------------------------------------------------
require_no_arguments "$@" || exit 2
find_baselines
check_old_containers_unchanged
check_old_folders_unchanged
report_check Coexistence "the old layout was disturbed" \
  "old containers and old folders untouched ($compared)"
