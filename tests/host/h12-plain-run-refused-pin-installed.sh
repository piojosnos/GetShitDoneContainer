#!/usr/bin/env bash
# H-12: a plain docker run is refused by the start check, and the installed Claude Code
# version is the pinned one from claude/Dockerfile.
# Depends on: nothing
# Needs: images built
set -u
. "$(dirname "$0")/lib.sh"
host_init

pin=$(claude_pin)
plainOutput=$(docker run --rm sbx-claude:local claude --version </dev/null 2>&1)
plainStatus=$?
pinOutput=$(docker run --rm --entrypoint claude sbx-claude:local --version </dev/null 2>&1)
plainProblem=""
pinProblem=""

if [ "$plainStatus" -ne 1 ] || [[ "$plainOutput" != *"[sbx] ERROR"* ]] || [[ "$plainOutput" != *"not a bind mount"* ]]; then
  plainProblem="a plain docker run must exit 1 with '[sbx] ERROR' and 'not a bind mount'; got exit $plainStatus: $(printf '%s\n' "$plainOutput" | head -n 3 | tr '\n' ' ')"
fi

if [ -z "$pin" ] || [ "$pinOutput" != "$pin (Claude Code)" ]; then
  pinProblem="expected '$pin (Claude Code)'; got: $pinOutput"
fi

set --
if [ -n "$plainProblem" ]; then
  set -- "$@" "$plainProblem"
fi
if [ -n "$pinProblem" ]; then
  set -- "$@" "$pinProblem"
fi

if [ "$#" -gt 0 ]; then
  fail H-12 "the start check or the pinned version is wrong" "$@"
  exit 1
fi

pass H-12 "a plain docker run is refused and Claude Code $pin is installed"
exit 0
