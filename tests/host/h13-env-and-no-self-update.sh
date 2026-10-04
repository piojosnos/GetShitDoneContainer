#!/usr/bin/env bash
# H-13: the environment is visible to docker exec, and Claude Code self-update is off.
# The claude doctor part needs a terminal: it is the manual helper (manual/h13-doctor.sh).
# Depends on: nothing
# Needs: test sandbox running
set -u
. "$(dirname "$0")/lib.sh"
host_init
require_test_sandbox H-13 || exit 1

envOutput=$(in_container env)
updateOutput=$(run_timeout 60 in_container claude update)
in_container sh -c 'test ! -e "$HOME/.local/share/claude"' >/dev/null
shareStatus=$?

set --

for envName in CLAUDE_CONFIG_DIR DISABLE_UPDATES HISTFILE GH_CONFIG_DIR GIT_CONFIG_GLOBAL; do
  if ! printf '%s\n' "$envOutput" | grep -q "^$envName="; then
    set -- "$@" "$envName is not set in docker exec"
  fi
done

if [[ "$updateOutput" != *"Updates are disabled by your administrator"* ]]; then
  set -- "$@" "claude update did not say updates are disabled; got: $(printf '%s\n' "$updateOutput" | head -n 3 | tr '\n' ' ')"
fi

if [ "$shareStatus" -ne 0 ]; then
  set -- "$@" "~/.local/share/claude exists in the container home"
fi

if [ "$#" -gt 0 ]; then
  fail H-13 "the environment or the no-self-update setup is wrong" "$@"
  exit 1
fi

pass H-13 "five variables are set, claude update is disabled, no ~/.local/share/claude"
exit 0
