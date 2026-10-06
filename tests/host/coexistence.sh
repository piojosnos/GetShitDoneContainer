#!/usr/bin/env bash
# Coexistence: the old-layout containers and folders are untouched.
# - Compares the old container list taken at the start of the run (in the run folder's logs)
#   with the list now, and checks git status for ClaudeCode/ and OpenCode/.
# - Only reads. Writes one file, logs/old-containers.after, in the run folder.
# - Alone, with no start-of-run list, it checks git only.
# Depends on: nothing (compares with the snapshot run-all.sh takes at the start)
# Needs: nothing
set -u
. "$(dirname "$0")/lib.sh"
host_init

baselineFile=""
compared="git only; no baseline"

# --------------------------------------------------------------------------------
# Finds the old container list run-all.sh took at the start of the run
# --------------------------------------------------------------------------------
find_baseline() {
  if [ -n "$RUN" ] && [ -f "$RUN/logs/old-containers.before" ]; then
    baselineFile="$RUN/logs/old-containers.before"
  fi
}

# --------------------------------------------------------------------------------
# Compares the old container list now with the one from the start of the run
# --------------------------------------------------------------------------------
check_old_containers_unchanged() {
  local afterFile

  if [ -z "$baselineFile" ]; then
    return
  fi

  afterFile="$RUN/logs/old-containers.after"
  snapshot_old_containers >"$afterFile"
  compared="container snapshot and git"

  if ! cmp -s "$baselineFile" "$afterFile"; then
    add_problem "the old containers changed during the run"
    add_problem "before: $(tr '\n' ';' <"$baselineFile")"
    add_problem "after:  $(tr '\n' ';' <"$afterFile")"
    add_problem "if you started or stopped a cc_ container during the run, re-run"
  fi
}

# --------------------------------------------------------------------------------
# Checks git shows no change under ClaudeCode/ or OpenCode/
# --------------------------------------------------------------------------------
check_old_folders_clean() {
  local gitOutput

  gitOutput=$(git -C "$REPO_DIR" status --porcelain --untracked-files=all -- ClaudeCode OpenCode 2>&1)
  if [ -n "$gitOutput" ]; then
    add_problem "git status shows changes under ClaudeCode/ or OpenCode/: $(join_lines "$gitOutput" ';')"
  fi
}

# --------------------------------------------------------------------------------
# Main / Entry Point
# --------------------------------------------------------------------------------
require_no_arguments "$@" || exit 2
find_baseline
check_old_containers_unchanged
check_old_folders_clean
report_check Coexistence "the old layout was disturbed" \
  "old containers and old folders untouched ($compared)"
