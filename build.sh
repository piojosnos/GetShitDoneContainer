#!/usr/bin/env bash
# ------------------------------------------------------------------------------
# Builds sbx-base:local, then sbx-claude:local, with the pins in versions.env
# ------------------------------------------------------------------------------
# Usage: ./build.sh [DOCKER_BUILD_OPTION...]
# Extra options go to both builds, for example --no-cache.
# ------------------------------------------------------------------------------
set -eu

# ------------------------------------------------------------------------------
# check_versions_file: stops when versions.env is not next to this script
# ------------------------------------------------------------------------------
check_versions_file() {
  if [ ! -f ./versions.env ]; then
    echo "build.sh: versions.env is missing next to build.sh" >&2
    exit 1
  fi
}

# ------------------------------------------------------------------------------
# load_versions: exports every NAME=value line of versions.env
# ------------------------------------------------------------------------------
# The file is read by bash, so it is code. The ./ stops a PATH search for it.
# ------------------------------------------------------------------------------
load_versions() {
  set -a
  source ./versions.env
  set +a
}

# ------------------------------------------------------------------------------
# collect_build_args: fills buildArgList with a --build-arg per pin
# ------------------------------------------------------------------------------
# A bare NAME has no value here: Docker reads it from the environment.
# So adding or bumping a pin never changes this file.
# ------------------------------------------------------------------------------
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

# ------------------------------------------------------------------------------
# build_image DOCKERFILE TAG [OPTION...]: builds TAG with every pin
# ------------------------------------------------------------------------------
# The options come right after docker build.
# ------------------------------------------------------------------------------
build_image() {
  local dockerfile=$1
  local imageTag=$2

  shift 2

  echo "build.sh: building $imageTag"
  docker build "$@" -f "$dockerfile" "${buildArgList[@]}" -t "$imageTag" .
}

# ------------------------------------------------------------------------------
# Main / Entry Point
# ------------------------------------------------------------------------------
cd "$(dirname "$0")"

check_versions_file
load_versions
collect_build_args
build_image base/Dockerfile sbx-base:local "$@"
build_image claude/Dockerfile sbx-claude:local "$@"
