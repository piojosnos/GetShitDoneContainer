#!/usr/bin/env bash
# H-01: both images and the container run natively (no emulation).
# Depends on: nothing
# Needs: test sandbox running
set -u
. "$(dirname "$0")/lib.sh"
host_init

# --------------------------------------------------------------------------------
# Reads the expected and the reported architecture; FAIL and return 1 if the daemon reports one this check does not know
# --------------------------------------------------------------------------------
require_known_architecture() {
  expected=$(expected_arch)
  rawArch=$(docker info --format '{{.Architecture}}' </dev/null 2>&1)

  if [ "$expected" = "unknown" ]; then
    fail H-01 "the daemon reports an architecture this check does not know" "docker info says: $rawArch"
    return 1
  fi
}

# --------------------------------------------------------------------------------
# Checks both images were built for the daemon's architecture
# --------------------------------------------------------------------------------
check_image_architectures() {
  local imageName
  local imageArch

  for imageName in sbx-base:local sbx-claude:local; do
    imageArch=$(docker image inspect --format '{{.Architecture}}' "$imageName" </dev/null 2>&1)
    if [ "$imageArch" != "$expected" ]; then
      add_problem "$imageName is $imageArch; expected $expected"
    fi
  done
}

# --------------------------------------------------------------------------------
# Checks the container reports the same architecture as the daemon
# --------------------------------------------------------------------------------
check_container_architecture() {
  containerArch=$(in_container uname -m)
  if [ "$containerArch" != "$rawArch" ]; then
    add_problem "uname -m in the container is $containerArch; the daemon reports $rawArch"
  fi
}

# --------------------------------------------------------------------------------
# Checks no build, rebuild or start log of this run has the BuildKit or the docker run platform warning
# --------------------------------------------------------------------------------
# The two phrases: "does not match the detected host platform" (docker run) and InvalidBaseImagePlatform (BuildKit).
check_no_platform_warnings() {
  local logFile
  local warningLogs=""

  for logFile in "$RUN"/logs/build-*.log "$RUN"/logs/rebuild-*.log "$RUN"/logs/compose-up.log; do
    if [ -f "$logFile" ] && grep -Eq 'does not match the detected host platform|InvalidBaseImagePlatform' "$logFile"; then
      warningLogs="$warningLogs$logFile "
    fi
  done

  if [ -n "$warningLogs" ]; then
    add_problem "platform mismatch warning in: $warningLogs"
  fi
}

# --------------------------------------------------------------------------------
# Main / Entry Point
# --------------------------------------------------------------------------------
require_no_arguments "$@" || exit 2
require_test_sandbox H-01 || exit 1
require_known_architecture || exit 1
check_image_architectures
check_container_architecture
check_no_platform_warnings
report_check H-01 "the images or the container are not native ($expected)" \
  "both images are $expected and the container reports $containerArch"
