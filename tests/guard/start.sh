#!/usr/bin/env bash
# Guard rules on the container start: nothing is installed at start, start hooks have orderly names, and Compose checks the sandbox name before it acts.
# - Run by tests/guard/run-all.sh; runs alone too.
# - Usage, from anywhere: bash tests/guard/start.sh   (exit 0 = every rule holds)
set -u
. "$(dirname "$0")/lib.sh"

# --------------------------------------------------------------------------------
# no_installs_at_container_start: Nothing is installed when the container starts: the image is the only source of tools.
# --------------------------------------------------------------------------------
# This covers the entrypoint and every start hook.
no_installs_at_container_start() {
  nowhere_matches '\b(npm|npx|bunx|pip|apt-get|apt|curl|wget)\b' $ENTRY claude/start.d/*
}

# --------------------------------------------------------------------------------
# start_hooks_have_two_digit_names: Start hooks run in text order, so every hook name is two digits, a hyphen, then lowercase letters, digits or hyphens
# --------------------------------------------------------------------------------
# (a name like 100- would sort before 20-).
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

# --------------------------------------------------------------------------------
# compose_starts_in_the_workspace: Compose starts the container in the workspace, never in the project folder: Docker creates a missing working directory, which would put a folder on the Mac for a mistyped name.
# --------------------------------------------------------------------------------
# The entrypoint checks that the project folder exists and moves into it.
compose_starts_in_the_workspace() {
  local ok=0

  nowhere_matches 'working_dir:.*SBX_NAME' $COMPOSE || ok=1

  if ! grep -Eq '^[[:space:]]*working_dir:[[:space:]]*"?/home/sandbox/workspace"?[[:space:]]*$' $COMPOSE; then
    echo "    $COMPOSE has no working_dir line set to /home/sandbox/workspace"
    ok=1
  fi

  return "$ok"
}

# --------------------------------------------------------------------------------
# compose_checks_the_name_before_it_acts: compose.yml keeps the name-check service: its image name holds SBX_NAME, so up refuses an uppercase letter before it creates anything, and it never runs a container (scale 0, never pulled, no mount, port or command)
# --------------------------------------------------------------------------------
# The block runs from the line "  name-check:" to the next line indented by two spaces or less.
compose_checks_the_name_before_it_acts() {
  local ok=0
  local blockText
  local trimmedText
  local requiredLine

  blockText=$(awk '
    /^  name-check:[[:space:]]*$/ { inBlock = 1; next }
    inBlock && /^[[:space:]]*$/ { next }
    inBlock && (/^[^ ]/ || /^ [^ ]/ || /^  [^ ]/) { inBlock = 0 }
    inBlock { print }
  ' $COMPOSE)

  if [ -z "$blockText" ]; then
    echo "    $COMPOSE has no name-check service"
    return 1
  fi

  trimmedText=$(printf '%s\n' "$blockText" | sed 's/^[[:space:]]*//')

  for requiredLine in 'image: "sbx-${SBX_NAME}-name-check"' 'pull_policy: never' 'scale: 0'; do
    if ! printf '%s\n' "$trimmedText" | grep -Fxq -- "$requiredLine"; then
      echo "    the name-check service in $COMPOSE lacks the line: $requiredLine"
      ok=1
    fi
  done

  if printf '%s\n' "$trimmedText" | grep -Eq '^(volumes|ports|command|entrypoint):'; then
    echo "    the name-check service in $COMPOSE must not run anything: $(printf '%s\n' "$trimmedText" | grep -E '^(volumes|ports|command|entrypoint):' | head -n 1)"
    ok=1
  fi

  return "$ok"
}

# --------------------------------------------------------------------------------
# Main / Entry Point
# --------------------------------------------------------------------------------
require_no_arguments "$@" || exit 2
enter_repo_root || exit 1
run_rules \
  no_installs_at_container_start \
  start_hooks_have_two_digit_names \
  compose_starts_in_the_workspace \
  compose_checks_the_name_before_it_acts || exit 1
