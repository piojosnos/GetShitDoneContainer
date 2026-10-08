#!/usr/bin/env bash
# Builds sbx-base:local, then sbx-claude:local, with the pins in versions.env.
# - versions.env is the only place versions live. The Dockerfiles have no default versions,
#   so a build that skips this script stops and names the missing pin instead of building
#   an old version.
# - Every NAME in versions.env goes to both builds as a bare --build-arg NAME, and Docker
#   takes the value from the environment this script exported. Adding or bumping a pin
#   never changes this file.
# - Extra arguments go to both docker build calls, for example: ./build.sh --no-cache
# - Runs from any folder. The repo root is the build context.
# - Stock bash 3.2 (macOS).
# - Usage: ./build.sh [DOCKER_BUILD_OPTION...]
set -eu

# --------------------------------------------------------------------------------
# check_versions_file: stops with a message when versions.env is not next to this script.
# --------------------------------------------------------------------------------
check_versions_file() {
  if [ ! -f ./versions.env ]; then
    echo "build.sh: versions.env is missing next to build.sh" >&2
    exit 1
  fi
}

# --------------------------------------------------------------------------------
# load_versions: exports every NAME=value line of versions.env into this script's environment.
# --------------------------------------------------------------------------------
# The file is read by bash, so it is code. The ./ keeps bash from searching PATH for it.
load_versions() {
  set -a
  source ./versions.env
  set +a
}

# --------------------------------------------------------------------------------
# collect_build_args: fills buildArgList with one --build-arg NAME per name in versions.env; stops when there is none.
# --------------------------------------------------------------------------------
# A bare NAME has no value here: Docker reads it from the environment load_versions filled.
collect_build_args() {
  local pinName
  local pinCount=0

  buildArgList=()

  for pinName in $(grep -oE '^[A-Z_]+' versions.env); do
    buildArgList+=(--build-arg "$pinName")
    pinCount=$((pinCount + 1))
  done

  if [ "$pinCount" -eq 0 ]; then
    echo "build.sh: versions.env holds no pins" >&2
    exit 1
  fi
}

# --------------------------------------------------------------------------------
# build_image DOCKERFILE TAG [DOCKER_OPTION...]: builds TAG from DOCKERFILE with every pin; the options come right after docker build.
# --------------------------------------------------------------------------------
build_image() {
  local dockerfile=$1
  local imageTag=$2

  shift 2

  echo "build.sh: building $imageTag"
  docker build "$@" -f "$dockerfile" "${buildArgList[@]}" -t "$imageTag" .
}

# --------------------------------------------------------------------------------
# Main / Entry Point
# --------------------------------------------------------------------------------
cd "$(dirname "$0")"

check_versions_file
load_versions
collect_build_args
build_image base/Dockerfile sbx-base:local "$@"
build_image claude/Dockerfile sbx-claude:local "$@"
