#!/usr/bin/env bash
# ------------------------------------------------------------------------------
# H-12: a plain docker run is refused
# ------------------------------------------------------------------------------
# Needs: images built
# ------------------------------------------------------------------------------
set -u
. "$(dirname "$0")/lib.sh"
host_init

# ------------------------------------------------------------------------------
# Runs the Claude test image once, plainly
# ------------------------------------------------------------------------------
run_containers() {
  plainOutput=$(docker run --rm "$CLAUDE_IMAGE" claude --version </dev/null 2>&1)
  plainStatus=$?
}

# ------------------------------------------------------------------------------
# Checks a plain docker run is refused by the start check
# ------------------------------------------------------------------------------
check_plain_run_refused() {
  if [ "$plainStatus" -ne 1 ] || [[ "$plainOutput" != *"[sbx] ERROR"* ]] || [[ "$plainOutput" != *"not a mount point"* ]]; then
    add_problem "a plain docker run must exit 1 with '[sbx] ERROR' and 'not a mount point'; got exit $plainStatus: $(first_lines "$plainOutput")"
  fi
}

# ------------------------------------------------------------------------------
# Main / Entry Point
# ------------------------------------------------------------------------------
require_no_arguments "$@" || exit 2
run_containers
check_plain_run_refused
report_check H-12 "a plain docker run was not refused" "a plain docker run is refused"
