#!/usr/bin/env bash
# ------------------------------------------------------------------------------
# H-13 helper: claude doctor in the test sandbox shows auto-updates disabled
# ------------------------------------------------------------------------------
# Usage: bash tests/host/manual/h13-doctor.sh (exit 0 = PASS)
# Needs a terminal and the test sandbox that tests/host/run-all.sh leaves up.
# ------------------------------------------------------------------------------
set -u

. "$(dirname "$0")/lib-manual.sh"
require_terminal

. "$(dirname "$0")/../lib.sh"
host_init

# ------------------------------------------------------------------------------
# Main / Entry Point
# ------------------------------------------------------------------------------
require_no_arguments "$@" || exit 2
require_test_sandbox H-13 || exit 1
printf 'claude doctor runs next, inside the test sandbox.\n'
printf '  Look for: auto-updates shown as disabled.\n'
printf '  If it waits for a key, press Enter or Esc to come back here.\n\n'
run_claude doctor
printf '\n'
ask_judgment H-13 "Did claude doctor show auto-updates disabled?" \
  "claude doctor shows auto-updates disabled" \
  "claude doctor did not show auto-updates disabled"
exit_with_result
