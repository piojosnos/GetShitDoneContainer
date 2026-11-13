#!/usr/bin/env bash
# ------------------------------------------------------------------------------
# Guard rules on the container start: ordered hooks, GSD first
# ------------------------------------------------------------------------------
# Usage: bash tests/guard/start.sh (exit 0 = every rule holds)
# ------------------------------------------------------------------------------
set -u
. "$(dirname "$0")/lib.sh"

# ------------------------------------------------------------------------------
# start_hooks_have_two_digit_names: NN-name, so 100- cannot sort before 20-
# ------------------------------------------------------------------------------
start_hooks_have_two_digit_names() {
  local hookNames

  hookNames=$(find claude/start.d -type f 2>/dev/null | sed 's#.*/##')

  if [ -z "$hookNames" ]; then
    echo "    claude/start.d holds no start hook"
    return 1
  fi

  printf '%s\n' "$hookNames" | grep -Ev '^[0-9]{2}-[a-z0-9-]+$' | report_lines "start hook name is not NN-name (lowercase, digits, hyphens): "
}

# ------------------------------------------------------------------------------
# gsd_sync_runs_before_the_bundle: GSD syncs first, so a bundle skill wins
# ------------------------------------------------------------------------------
gsd_sync_runs_before_the_bundle() {
  local ok=0
  local hook
  local hookList

  hookList=$(grep -lF 'gsd-core --claude' claude/start.d/* 2>/dev/null)

  if [ -z "$hookList" ]; then
    echo "    no start hook runs the GSD installer"
    return 1
  fi

  for hook in $hookList; do
    if ! [[ "$(basename "$hook")" < "10-best-practices" ]]; then
      echo "    $hook sorts after 10-best-practices"
      ok=1
    fi
  done

  return "$ok"
}

# ------------------------------------------------------------------------------
# Main / Entry Point
# ------------------------------------------------------------------------------
require_no_arguments "$@" || exit 2
enter_repo_root || exit 1
run_rules \
  start_hooks_have_two_digit_names \
  gsd_sync_runs_before_the_bundle || exit 1
