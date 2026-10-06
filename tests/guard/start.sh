#!/usr/bin/env bash
# Guard rules on the container start: nothing is installed at start, and start hooks have orderly names.
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
# Main / Entry Point
# --------------------------------------------------------------------------------
require_no_arguments "$@" || exit 2
enter_repo_root || exit 1
run_rules \
  no_installs_at_container_start \
  start_hooks_have_two_digit_names || exit 1
