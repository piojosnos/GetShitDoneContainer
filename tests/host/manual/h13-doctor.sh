#!/usr/bin/env bash
# H-13 (attended): run claude doctor in the test sandbox and confirm it reports auto-updates disabled.
# - Needs a terminal. Run it after bash tests/host/run-all.sh, against the same test sandbox
#   (sbx-hosttest). It finds the run folder from the container's mount.
# - The environment variables, claude update and the missing ~/.local/share/claude are checked
#   automatically by tests/host/h13-env-and-no-self-update.sh; only the doctor wording needs you.
# - Usage: bash tests/host/manual/h13-doctor.sh   (exit 0 = PASS)
set -u

. "$(dirname "$0")/lib-manual.sh"
require_terminal

. "$(dirname "$0")/../lib.sh"
host_init
require_test_sandbox H-13 || exit 1

# --------------------------------------------------------------------------------
# Main / Entry Point
# --------------------------------------------------------------------------------
printf 'claude doctor runs next, inside the test sandbox.\n'
printf '  Look for: auto-updates shown as disabled.\n'
printf '  If it waits for a key, press Enter or Esc to come back here.\n\n'
run_claude doctor
printf '\n'
ask_judgment H-13 "Did claude doctor show auto-updates disabled?" \
  "claude doctor shows auto-updates disabled" \
  "claude doctor did not show auto-updates disabled"
exit_with_result
