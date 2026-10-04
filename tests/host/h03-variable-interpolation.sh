#!/usr/bin/env bash
# H-03: variables reach compose.yml. The project name is sbx-hosttest, and a missing
# SBX_DIR is refused with a message that names it.
# Depends on: nothing
# Needs: nothing
set -u
. "$(dirname "$0")/lib.sh"
host_init

if [ -n "$RUN" ]; then
  nameOutput=$(compose_cmd config 2>&1)
else
  nameOutput=$(SBX_NAME=hosttest SBX_DIR=/sbx-hosttest-config-only docker compose -f "$REPO_DIR/compose.yml" config </dev/null 2>&1)
fi

missingOutput=$(env -u SBX_DIR SBX_NAME=hosttest docker compose -f "$REPO_DIR/compose.yml" config </dev/null 2>&1)
missingStatus=$?
nameProblem=""
missingProblem=""

if ! printf '%s\n' "$nameOutput" | grep -Fxq 'name: sbx-hosttest'; then
  nameProblem="expected the line 'name: sbx-hosttest' in the config; got: $(printf '%s\n' "$nameOutput" | head -n 3 | tr '\n' ' ')"
fi

if [ "$missingStatus" -eq 0 ] || [[ "$missingOutput" != *"SBX_DIR is required"* ]]; then
  missingProblem="expected 'SBX_DIR is required' and a non-zero exit without SBX_DIR; got exit $missingStatus: $(printf '%s\n' "$missingOutput" | head -n 3 | tr '\n' ' ')"
fi

set --
if [ -n "$nameProblem" ]; then
  set -- "$@" "$nameProblem"
fi
if [ -n "$missingProblem" ]; then
  set -- "$@" "$missingProblem"
fi

if [ "$#" -gt 0 ]; then
  fail H-03 "variable interpolation is wrong" "$@"
  exit 1
fi

pass H-03 "the project name is sbx-hosttest and a missing SBX_DIR is refused by name"
exit 0
