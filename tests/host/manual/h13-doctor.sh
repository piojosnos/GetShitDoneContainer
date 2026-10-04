#!/usr/bin/env bash
# H-13 (attended): run claude doctor in the test sandbox and confirm it reports auto-updates disabled.
# - Needs a terminal. Run it after bash tests/host/run-all.sh, against the same test sandbox
#   (sbx-hosttest). It finds the run folder from the container's mount.
# - The environment variables, claude update and the missing ~/.local/share/claude are checked
#   automatically by tests/host/h13-env-and-no-self-update.sh; only the doctor wording needs you.
# - Usage: bash tests/host/manual/h13-doctor.sh   (exit 0 = PASS)
set -u

if [ ! -t 0 ] || [ ! -t 1 ]; then
  printf 'This helper needs a terminal. Run it directly, not through a pipe or a script.\n' >&2
  exit 1
fi

. "$(dirname "$0")/../lib.sh"
host_init
require_test_sandbox H-13 || exit 1

printf 'claude doctor runs next, inside the test sandbox.\n'
printf '  Look for: auto-updates shown as disabled.\n'
printf '  If it waits for a key, press Enter or Esc to come back here.\n\n'

docker exec -it -w /home/sandbox/workspace/hosttest "$CONTAINER" claude doctor

printf '\nDid claude doctor show auto-updates disabled? [y/N] '
read -r answer

case "$answer" in
  y|Y)
    pass H-13 "claude doctor shows auto-updates disabled"
    exit 0
    ;;
esac

fail H-13 "claude doctor did not show auto-updates disabled" "answer: ${answer:-<none>}"
exit 1
