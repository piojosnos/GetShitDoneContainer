#!/usr/bin/env bash
# H-12: a plain docker run is refused by the start check, and the installed Claude Code
# version is the pinned one from claude/Dockerfile.
# Depends on: nothing
# Needs: images built
set -u
. "$(dirname "$0")/lib.sh"
host_init

# --------------------------------------------------------------------------------
# Runs the image once plain and once with claude as the entrypoint
# --------------------------------------------------------------------------------
run_containers() {
  pin=$(claude_pin)
  plainOutput=$(docker run --rm sbx-claude:local claude --version </dev/null 2>&1)
  plainStatus=$?
  pinOutput=$(docker run --rm --entrypoint claude sbx-claude:local --version </dev/null 2>&1)
}

# --------------------------------------------------------------------------------
# Checks a plain docker run is refused by the start check
# --------------------------------------------------------------------------------
check_plain_run_refused() {
  if [ "$plainStatus" -ne 1 ] || [[ "$plainOutput" != *"[sbx] ERROR"* ]] || [[ "$plainOutput" != *"not a bind mount"* ]]; then
    add_problem "a plain docker run must exit 1 with '[sbx] ERROR' and 'not a bind mount'; got exit $plainStatus: $(first_lines "$plainOutput")"
  fi
}

# --------------------------------------------------------------------------------
# Checks the installed Claude Code is the pinned version
# --------------------------------------------------------------------------------
check_pin_installed() {
  if [ -z "$pin" ] || [ "$pinOutput" != "$pin (Claude Code)" ]; then
    add_problem "expected '$pin (Claude Code)'; got: $pinOutput"
  fi
}

# --------------------------------------------------------------------------------
# Main / Entry Point
# --------------------------------------------------------------------------------
require_no_arguments "$@" || exit 2
run_containers
check_plain_run_refused
check_pin_installed
report_check H-12 "the start check or the pinned version is wrong" \
  "a plain docker run is refused and Claude Code $pin is installed"
