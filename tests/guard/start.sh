#!/usr/bin/env bash
# ------------------------------------------------------------------------------
# Guard rules on the container start: ordered hooks, GSD first, agent image, tag
# ------------------------------------------------------------------------------
# Usage: bash tests/guard/start.sh (exit 0 = every rule holds)
# ------------------------------------------------------------------------------
set -u
. "$(dirname "$0")/lib.sh"

# ------------------------------------------------------------------------------
# start_hooks_have_two_digit_names: NN-name, so 100- cannot sort before 20-
# ------------------------------------------------------------------------------
start_hooks_have_two_digit_names() {
  local hookDir
  local hookNames
  local ok=0

  for hookDir in $HOOK_DIRS; do
    hookNames=$(find "$hookDir" -type f 2>/dev/null | sed 's#.*/##')

    if [ -z "$hookNames" ]; then
      echo "    $hookDir holds no start hook"
      ok=1
      continue
    fi

    if ! printf '%s\n' "$hookNames" | grep -Ev '^[0-9]{2}-[a-z0-9-]+$' | report_lines "start hook name is not NN-name (lowercase, digits, hyphens): "; then
      ok=1
    fi
  done

  return "$ok"
}

# ------------------------------------------------------------------------------
# gsd_sync_runs_before_the_bundle: GSD syncs first, so a bundle skill wins
# ------------------------------------------------------------------------------
# Each agent folder must hold its own GSD hook.
# ------------------------------------------------------------------------------
gsd_sync_runs_before_the_bundle() {
  local ok=0
  local hook
  local hookDir
  local hookList

  for hookDir in $HOOK_DIRS; do
    hookList=$(grep -lE 'gsd-core --(claude|cursor) ' "$hookDir"/* 2>/dev/null)

    if [ -z "$hookList" ]; then
      echo "    $hookDir has no start hook that runs the GSD installer"
      ok=1
      continue
    fi

    for hook in $hookList; do
      if ! [[ "$(basename "$hook")" < "10-best-practices" ]]; then
        echo "    $hook sorts after 10-best-practices"
        ok=1
      fi
    done
  done

  return "$ok"
}

# ------------------------------------------------------------------------------
# compose_image_follows_agent_and_tag: the agent and the tag pick the image
# ------------------------------------------------------------------------------
# compose.yml falls back to claude and local when a variable is unset, so a lost
# hand-off would start a Cursor sandbox on the Claude image, or a test sandbox
# on the images the user's sandboxes run. An agent build without the base of its
# own tag would sit on the local base.
# ------------------------------------------------------------------------------
compose_image_follows_agent_and_tag() {
  local ok=0
  local baseArgCount

  if ! grep -Fq 'image: "sbx-${SBX_AGENT:-claude}:${SBX_IMAGE_TAG:-local}"' $COMPOSE; then
    echo "    $COMPOSE does not take its image from \"sbx-\${SBX_AGENT:-claude}:\${SBX_IMAGE_TAG:-local}\""
    ok=1
  fi

  if ! grep -Fq 'SBX_AGENT="$entryAgent" docker compose' bin/sbx-lib.sh; then
    echo "    bin/sbx-lib.sh does not pass SBX_AGENT=\"\$entryAgent\" to docker compose"
    ok=1
  fi

  if ! grep -Fq 'SBX_IMAGE_TAG="$imageTag"' bin/sbx-lib.sh; then
    echo "    bin/sbx-lib.sh does not pass SBX_IMAGE_TAG=\"\$imageTag\" to docker compose"
    ok=1
  fi

  baseArgCount=$(grep -Ev '^[[:space:]]*#' build.sh | grep -cF -- '--build-arg "BASE_IMAGE=sbx-base:$imageTag"')

  if [ "$baseArgCount" -ne 2 ]; then
    echo "    build.sh does not pass the base of its own tag to both agent builds"
    ok=1
  fi

  return "$ok"
}

# ------------------------------------------------------------------------------
# Main / Entry Point
# ------------------------------------------------------------------------------
require_no_arguments "$@" || exit 2
enter_repo_root || exit 1
run_rules \
  start_hooks_have_two_digit_names \
  gsd_sync_runs_before_the_bundle \
  compose_image_follows_agent_and_tag || exit 1
