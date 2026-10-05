#!/usr/bin/env bash
# H-01: both images and the container run natively (no emulation).
# Depends on: nothing
# Needs: test sandbox running
set -u
. "$(dirname "$0")/lib.sh"
host_init
require_test_sandbox H-01 || exit 1

# --------------------------------------------------------------------------------
# Reads the expected and the reported architecture; stops if the daemon reports one this check does not know
# --------------------------------------------------------------------------------
require_known_architecture() {
  expected=$(expected_arch)
  rawArch=$(docker info --format '{{.Architecture}}' </dev/null 2>&1)

  if [ "$expected" = "unknown" ]; then
    stop_check H-01 "the daemon reports an architecture this check does not know" "docker info says: $rawArch"
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
# Checks no log of this run warns about a platform mismatch
# --------------------------------------------------------------------------------
check_no_platform_warnings() {
  local warningCount
  local warningLogs

  warningCount=$(cat "$RUN"/logs/*.log 2>/dev/null | grep -Fc "does not match")
  if [ "$warningCount" -gt 0 ]; then
    warningLogs=$(grep -Fl "does not match" "$RUN"/logs/*.log 2>/dev/null | tr '\n' ' ')
    add_problem "platform mismatch warning in: $warningLogs"
  fi
}

# --------------------------------------------------------------------------------
# Main / Entry Point
# --------------------------------------------------------------------------------
require_known_architecture
check_image_architectures
check_container_architecture
check_no_platform_warnings
report_check H-01 "the images or the container are not native ($expected)" \
  "both images are $expected and the container reports $containerArch"
