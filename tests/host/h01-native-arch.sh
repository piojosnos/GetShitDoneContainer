#!/usr/bin/env bash
# H-01: both images and the container run natively (no emulation).
# Depends on: nothing
# Needs: test sandbox running
set -u
. "$(dirname "$0")/lib.sh"
host_init
require_test_sandbox H-01 || exit 1

expected=$(expected_arch)
rawArch=$(docker info --format '{{.Architecture}}' </dev/null 2>&1)

if [ "$expected" = "unknown" ]; then
  fail H-01 "the daemon reports an architecture this check does not know" "docker info says: $rawArch"
  exit 1
fi

set --

for imageName in sbx-base:local sbx-claude:local; do
  imageArch=$(docker image inspect --format '{{.Architecture}}' "$imageName" </dev/null 2>&1)
  if [ "$imageArch" != "$expected" ]; then
    set -- "$@" "$imageName is $imageArch; expected $expected"
  fi
done

containerArch=$(in_container uname -m)
if [ "$containerArch" != "$rawArch" ]; then
  set -- "$@" "uname -m in the container is $containerArch; the daemon reports $rawArch"
fi

warningCount=$(cat "$RUN"/logs/*.log 2>/dev/null | grep -Fc "does not match")
if [ "$warningCount" -gt 0 ]; then
  warningLogs=$(grep -Fl "does not match" "$RUN"/logs/*.log 2>/dev/null | tr '\n' ' ')
  set -- "$@" "platform mismatch warning in: $warningLogs"
fi

if [ "$#" -gt 0 ]; then
  fail H-01 "the images or the container are not native ($expected)" "$@"
  exit 1
fi

pass H-01 "both images are $expected and the container reports $containerArch"
exit 0
