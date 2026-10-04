#!/usr/bin/env bash
# H-07 (attended): log in to Claude inside the test sandbox, then check where the login landed.
# - Needs a terminal. Run it after bash tests/host/run-all.sh, against the same test sandbox
#   (sbx-hosttest). It finds the run folder from the container's mount; there is no pointer file.
# - You log in with a claude.ai account, then type /exit. Three lines follow, PASS or FAIL each:
#   the login files are on the Mac, claude auth status says logged in, no ~/.claude.json at home.
# - Usage: bash tests/host/manual/h07-login.sh   (exit 0 = every line is PASS)
set -u

if [ ! -t 0 ] || [ ! -t 1 ]; then
  printf 'This helper needs a terminal. Run it directly, not through a pipe or a script.\n' >&2
  exit 1
fi

. "$(dirname "$0")/../lib.sh"
host_init
require_test_sandbox H-07 || exit 1

printf 'Claude opens next, inside the test sandbox.\n'
printf '  1. Log in with a claude.ai account.\n'
printf '  2. Type /exit to come back here.\n\n'

docker exec -it -w /home/sandbox/workspace/hosttest "$CONTAINER" claude

printf '\n'
stateDir="$RUN/state/claude"
failCount=0

set --

for stateFile in .claude.json .credentials.json; do
  if [ ! -f "$stateDir/$stateFile" ]; then
    set -- "$@" "missing on the Mac: $stateDir/$stateFile"
  fi
done

if [ ! -d "$stateDir/projects" ]; then
  set -- "$@" "missing on the Mac: $stateDir/projects/"
fi

if [ "$#" -gt 0 ]; then
  fail H-07 "the login files are not in the state folder" "$@"
  failCount=$((failCount + 1))
else
  pass H-07 ".claude.json, .credentials.json and projects/ are in $stateDir"
fi

authOutput=$(in_container claude auth status)

if printf '%s\n' "$authOutput" | grep -Eq '"loggedIn":[[:space:]]*true'; then
  pass H-07 'claude auth status shows "loggedIn": true'
else
  fail H-07 "claude auth status does not show a login" "got: $(printf '%s\n' "$authOutput" | head -n 3 | tr '\n' ' ')"
  failCount=$((failCount + 1))
fi

homeCount=$(in_container sh -c 'ls -a "$HOME" | grep -c "^\.claude\.json$"')

if [ "$homeCount" = "0" ]; then
  pass H-07 "no ~/.claude.json in the container home"
else
  fail H-07 "a ~/.claude.json sits in the container home" "count of .claude.json in the home listing: $homeCount"
  failCount=$((failCount + 1))
fi

if [ "$failCount" -gt 0 ]; then
  exit 1
fi

exit 0
