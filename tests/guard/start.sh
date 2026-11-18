#!/usr/bin/env bash
# ------------------------------------------------------------------------------
# Guard rules on the container start: no entrypoint, agent image, tag
# ------------------------------------------------------------------------------
# Usage: bash tests/guard/start.sh (exit 0 = every rule holds)
# ------------------------------------------------------------------------------
set -u
. "$(dirname "$0")/lib.sh"

# ------------------------------------------------------------------------------
# container_runs_no_entrypoint: a start only keeps the container alive
# ------------------------------------------------------------------------------
# sbx-init, run in a shell, sets the sandbox up. An entrypoint in an image or in
# compose would bring back setup that runs without anyone asking.
# ------------------------------------------------------------------------------
container_runs_no_entrypoint() {
  local ok=0

  if ! nowhere_matches '^ENTRYPOINT' $DOCKERFILES; then
    echo "    a Dockerfile sets an entrypoint"
    ok=1
  fi

  if ! nowhere_matches '^[[:space:]]*entrypoint:' $COMPOSE; then
    echo "    $COMPOSE sets an entrypoint"
    ok=1
  fi

  if ! grep -Fq 'init: true' $COMPOSE; then
    echo "    $COMPOSE does not keep \"init: true\""
    ok=1
  fi

  if ! grep -Fq 'command: ["sleep", "infinity"]' $COMPOSE; then
    echo "    $COMPOSE does not keep the command [\"sleep\", \"infinity\"]"
    ok=1
  fi

  return "$ok"
}

# ------------------------------------------------------------------------------
# agents_stay_off_the_path: only the wrappers start an agent
# ------------------------------------------------------------------------------
# The agents live in /opt/sbx/agents/bin so only their wrappers start them; a
# link in /usr/local/bin would let a plain shell run an uninitialised agent.
# ------------------------------------------------------------------------------
agents_stay_off_the_path() {
  local ok=0

  if ! grep -Fq '/opt/sbx/agents/bin/claude --version' $CLAUDE || ! grep -Fq '! command -v claude' $CLAUDE; then
    echo "    $CLAUDE has no smoke test that runs claude from /opt/sbx/agents/bin and fails when it is on the PATH"
    ok=1
  fi

  if ! grep -Fq '/opt/sbx/agents/bin/cursor-agent --version' $CURSOR || ! grep -Fq '! command -v cursor-agent' $CURSOR; then
    echo "    $CURSOR has no smoke test that runs cursor-agent from /opt/sbx/agents/bin and fails when it is on the PATH"
    ok=1
  fi

  if ! nowhere_matches 'ln -s [^ ]+ /usr/local/bin/(claude|cursor-agent)' $CLAUDE $CURSOR; then
    echo "    an agent Dockerfile links its agent into /usr/local/bin"
    ok=1
  fi

  return "$ok"
}

# ------------------------------------------------------------------------------
# compose_image_follows_agent_and_tag: the agent and the tag pick the image
# ------------------------------------------------------------------------------
# compose.yml falls back to claude and local when a variable is unset, so a lost
# hand-off would start a Cursor sandbox on the Claude image, or a test sandbox
# on the images the user's sandboxes run. An agent build without the base of its
# own tag would sit on the local base. build.sh reads the agent list and the tag
# check from bin/sbx-lib.sh, so a new agent or tag is one edit there.
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

  if ! grep -Fq 'for agent in $knownAgentList; do' build.sh; then
    echo "    build.sh does not build one image per agent in knownAgentList"
    ok=1
  fi

  baseArgCount=$(grep -Ev '^[[:space:]]*#' build.sh | grep -cF -- '--build-arg "BASE_IMAGE=sbx-base:$imageTag"')

  if [ "$baseArgCount" -ne 1 ]; then
    echo "    build.sh does not pass the base of its own tag to the agent builds"
    ok=1
  fi

  if grep -Eq '^(knownImageTagList|knownAgentList)=|^check_image_tag\(\)' build.sh; then
    echo "    build.sh defines its own agent list or tag check instead of reading bin/sbx-lib.sh"
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
  container_runs_no_entrypoint \
  agents_stay_off_the_path \
  compose_image_follows_agent_and_tag || exit 1
