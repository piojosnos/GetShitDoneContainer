#!/usr/bin/env bash
# ------------------------------------------------------------------------------
# Guard rules on the container start: no installs, ordered hooks, GSD first
# ------------------------------------------------------------------------------
# Usage: bash tests/guard/start.sh (exit 0 = every rule holds)
# Run by tests/guard/run-all.sh; runs alone too.
# ------------------------------------------------------------------------------
set -u
. "$(dirname "$0")/lib.sh"

# ------------------------------------------------------------------------------
# no_installs_at_container_start: the image is the only source of tools
# ------------------------------------------------------------------------------
# This covers the entrypoint and every start hook.
# ------------------------------------------------------------------------------
no_installs_at_container_start() {
  nowhere_matches '\b(npm|npx|bunx|pip|apt-get|apt|curl|wget)\b' $ENTRY claude/start.d/*
}

# ------------------------------------------------------------------------------
# start_hooks_have_two_digit_names: text order needs names like 20-name
# ------------------------------------------------------------------------------
# Two digits, a hyphen, then lowercase letters, digits or hyphens (a name like
# 100- would sort before 20-).
# ------------------------------------------------------------------------------
start_hooks_have_two_digit_names() {
  local hook
  local found=0
  local ok=0

  for hook in claude/start.d/*; do
    if [ ! -f "$hook" ]; then
      continue
    fi

    found=1
    if ! basename "$hook" | grep -Eq '^[0-9]{2}-[a-z0-9-]+$'; then
      echo "    $hook: the name must be two digits, a hyphen, then lowercase letters, digits or hyphens"
      ok=1
    fi
  done

  if [ "$found" -eq 0 ]; then
    echo "    claude/start.d holds no start hook"
    ok=1
  fi

  return "$ok"
}

# ------------------------------------------------------------------------------
# gsd_sync_runs_before_the_bundle: a bundle skill wins a name clash with GSD
# ------------------------------------------------------------------------------
# Every file in claude/start.d that holds the GSD installer call must sort
# before 10-best-practices.
# ------------------------------------------------------------------------------
gsd_sync_runs_before_the_bundle() {
  local hook
  local found=0
  local ok=0

  for hook in claude/start.d/*; do
    if [ ! -f "$hook" ]; then
      continue
    fi

    if ! grep -Fq 'gsd-core --claude' "$hook"; then
      continue
    fi

    found=1
    if ! [[ "$(basename "$hook")" < "10-best-practices" ]]; then
      echo "    $hook sorts after 10-best-practices"
      ok=1
    fi
  done

  if [ "$found" -eq 0 ]; then
    echo "    no start hook runs the GSD installer"
    ok=1
  fi

  return "$ok"
}

# ------------------------------------------------------------------------------
# compose_starts_in_the_workspace: no mistyped name makes a folder on the Mac
# ------------------------------------------------------------------------------
# Docker creates a missing working directory, so Compose must not start in the
# project folder. The entrypoint checks that it exists and moves into it.
# ------------------------------------------------------------------------------
compose_starts_in_the_workspace() {
  local ok=0

  nowhere_matches 'working_dir:.*SBX_NAME' $COMPOSE || ok=1

  if ! grep -Eq '^[[:space:]]*working_dir:[[:space:]]*"?/home/sandbox/workspace"?[[:space:]]*$' $COMPOSE; then
    echo "    $COMPOSE has no working_dir line set to /home/sandbox/workspace"
    ok=1
  fi

  return "$ok"
}

# ------------------------------------------------------------------------------
# agent_image_keeps_base_state_folders: the Claude image adds to the base list
# ------------------------------------------------------------------------------
# The base list must name cache/npm, cache/uv and m2; every assignment in the
# Claude image must start from ${SBX_STATE_DIRS}.
# ------------------------------------------------------------------------------
agent_image_keeps_base_state_folders() {
  local ok=0
  local folder
  local assignmentLine
  local baseAssignment

  baseAssignment=$(grep -E 'SBX_STATE_DIRS=' $BASE)

  for folder in cache/npm cache/uv m2; do
    if ! printf '%s\n' "$baseAssignment" | grep -Eq "SBX_STATE_DIRS=.*(^|[\" ])${folder}([\" ]|\$)"; then
      echo "    $BASE has no SBX_STATE_DIRS assignment holding $folder"
      ok=1
    fi
  done

  while IFS= read -r assignmentLine; do
    if [ -z "$assignmentLine" ]; then
      continue
    fi

    if ! printf '%s\n' "$assignmentLine" | grep -Fq '${SBX_STATE_DIRS}'; then
      echo "    $CLAUDE replaces SBX_STATE_DIRS instead of appending to it: $assignmentLine"
      ok=1
    fi
  done <<EOF_ASSIGNMENTS
$(grep -E 'SBX_STATE_DIRS=' $CLAUDE)
EOF_ASSIGNMENTS

  return "$ok"
}

# ------------------------------------------------------------------------------
# Main / Entry Point
# ------------------------------------------------------------------------------
require_no_arguments "$@" || exit 2
enter_repo_root || exit 1
run_rules \
  no_installs_at_container_start \
  start_hooks_have_two_digit_names \
  gsd_sync_runs_before_the_bundle \
  compose_starts_in_the_workspace \
  agent_image_keeps_base_state_folders || exit 1
