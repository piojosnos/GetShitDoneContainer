#!/usr/bin/env bash
# ------------------------------------------------------------------------------
# H-15: the clone is linked into state/claude and the container reads it
# ------------------------------------------------------------------------------
# Needs: test sandbox running
# The run folder's best-practices clone stands in for the real bundle repo.
# ------------------------------------------------------------------------------
set -u
. "$(dirname "$0")/lib.sh"
. "$(dirname "$0")/lib-bundle.sh"
host_init

cloneDir=$RUN/best-practices
configDir=$RUN/state/claude

# ------------------------------------------------------------------------------
# Checks the container reads the clone's rule through ~/.claude/rules
# ------------------------------------------------------------------------------
check_container_view() {
  local containerText macText

  containerText=$(in_container cat /home/sandbox/workspace/state/claude/rules/sbx-fixture-always.md)
  macText=$(cat "$cloneDir/rules/sbx-fixture-always.md" 2>&1)

  if [ "$containerText" != "$macText" ]; then
    add_problem "the container reads rules/sbx-fixture-always.md as '$(first_lines "$containerText")'; the clone holds '$(first_lines "$macText")'"
  fi
}

# ------------------------------------------------------------------------------
# Main / Entry Point
# ------------------------------------------------------------------------------
require_no_arguments "$@" || exit 2
require_test_sandbox H-15 || exit 1
check_bundle_links "$configDir" "$cloneDir"
check_container_view
report_check H-15 "the clone links or the container's view of the clone are wrong" \
  "state/claude links into the clone; the container reads the clone through ~/.claude/rules"
