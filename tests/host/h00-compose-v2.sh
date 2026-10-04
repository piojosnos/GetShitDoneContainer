#!/usr/bin/env bash
# H-00: Docker Compose is the v2 generation (version 2 or higher); prints the versions as info.
# Depends on: nothing
# Needs: Docker running
set -u
. "$(dirname "$0")/lib.sh"
host_init

composeVersion=$(docker compose version --short </dev/null 2>&1)
composeStatus=$?

if [ "$composeStatus" -ne 0 ]; then
  fail H-00 "docker compose version failed" "got: $composeVersion"
  exit 1
fi

composeVersion=${composeVersion#v}
majorVersion=${composeVersion%%.*}
dockerPlatform=$(docker version --format '{{.Server.Platform.Name}}' </dev/null 2>/dev/null || true)

info "Compose version $composeVersion"
info "Docker: ${dockerPlatform:-unknown}"

case "$majorVersion" in
  ''|*[!0-9]*)
    fail H-00 "could not read a Compose major version" "got: $composeVersion"
    exit 1
    ;;
esac

if [ "$majorVersion" -ge 2 ]; then
  pass H-00 "Compose $composeVersion is v2 or newer"
  exit 0
fi

fail H-00 "Compose $composeVersion is older than v2" "install Docker Desktop, which ships Compose v2"
exit 1
