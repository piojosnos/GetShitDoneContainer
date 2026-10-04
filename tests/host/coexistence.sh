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
if [ -n "$RUN" ] && [ -f "$RUN/logs/old-containers.before" ]; then
  baselineFile="$RUN/logs/old-containers.before"
fi

set --
compared="git only; no baseline"

if [ -n "$baselineFile" ]; then
  afterFile="$RUN/logs/old-containers.after"
  snapshot_old_containers >"$afterFile"
  compared="container snapshot and git"

  if ! cmp -s "$baselineFile" "$afterFile"; then
    set -- "$@" "the old containers changed during the run" \
      "before: $(tr '\n' ';' <"$baselineFile")" \
      "after:  $(tr '\n' ';' <"$afterFile")" \
      "if you started or stopped a cc_ container during the run, re-run"
  fi
fi

gitOutput=$(git -C "$REPO_DIR" status --porcelain --untracked-files=all -- ClaudeCode OpenCode 2>&1)
if [ -n "$gitOutput" ]; then
  set -- "$@" "git status shows changes under ClaudeCode/ or OpenCode/: $(printf '%s\n' "$gitOutput" | tr '\n' ';')"
fi

if [ "$#" -gt 0 ]; then
  fail Coexistence "the old layout was disturbed" "$@"
  exit 1
fi

pass Coexistence "old containers and old folders untouched ($compared)"
exit 0
