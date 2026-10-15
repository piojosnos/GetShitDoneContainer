#!/usr/bin/env bash
# ------------------------------------------------------------------------------
# Guard rules on the container start: no installs, ordered hooks, GSD first
# ------------------------------------------------------------------------------
# Usage: bash tests/guard/start.sh (exit 0 = every rule holds)
# ------------------------------------------------------------------------------
set -u
. "$(dirname "$0")/lib.sh"

# ------------------------------------------------------------------------------
# no_installs_at_container_start: the image is the only source of tools
# ------------------------------------------------------------------------------
no_installs_at_container_start() {
  nowhere_matches '\b(npm|npx|bunx|pip|apt-get|apt|curl|wget)\b' $ENTRY claude/start.d/*
}

# ------------------------------------------------------------------------------
# start_hooks_have_two_digit_names: NN-name, so 100- cannot sort before 20-
# ------------------------------------------------------------------------------
start_hooks_have_two_digit_names() {
  local hookNames

  hookNames=$(find claude/start.d -type f 2>/dev/null | sed 's#.*/##')

  if [ -z "$hookNames" ]; then
    echo "    claude/start.d holds no start hook"
    return 1
  fi

  printf '%s\n' "$hookNames" | grep -Ev '^[0-9]{2}-[a-z0-9-]+$' | report_lines "start hook name is not NN-name (lowercase, digits, hyphens): "
}

# ------------------------------------------------------------------------------
# gsd_sync_runs_before_the_bundle: GSD syncs first, so a bundle skill wins
# ------------------------------------------------------------------------------
gsd_sync_runs_before_the_bundle() {
  local ok=0
  local hook
  local hookList

  hookList=$(grep -lF 'gsd-core --claude' claude/start.d/* 2>/dev/null)

  if [ -z "$hookList" ]; then
    echo "    no start hook runs the GSD installer"
    return 1
  fi

  for hook in $hookList; do
    if ! [[ "$(basename "$hook")" < "10-best-practices" ]]; then
      echo "    $hook sorts after 10-best-practices"
      ok=1
    fi
  done

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
agent_image_keeps_base_state_folders() {
  local ok=0
  local folder

  for folder in cache/npm cache/uv m2; do
    if ! grep -E 'SBX_STATE_DIRS=' $BASE | grep -Eq "SBX_STATE_DIRS=.*(^|[\" ])${folder}([\" ]|\$)"; then
      echo "    $BASE has no SBX_STATE_DIRS assignment holding $folder"
      ok=1
    fi
  done

  grep -E 'SBX_STATE_DIRS=' $CLAUDE | grep -Fv '${SBX_STATE_DIRS}' | report_lines "$CLAUDE replaces SBX_STATE_DIRS instead of appending to it: " || ok=1

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
