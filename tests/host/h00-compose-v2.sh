#!/usr/bin/env bash
# H-00: Docker Compose is the v2 generation (version 2 or higher); prints the versions as info.
# Depends on: nothing
# Needs: Docker running
set -u
. "$(dirname "$0")/lib.sh"
host_init

# --------------------------------------------------------------------------------
# Reads the Compose and Docker versions and prints them as info
# --------------------------------------------------------------------------------
read_versions() {
  composeVersion=$(docker compose version --short </dev/null 2>&1)
  composeStatus=$?

  if [ "$composeStatus" -ne 0 ]; then
    stop_check H-00 "docker compose version failed" "got: $composeVersion"
  fi

  composeVersion=${composeVersion#v}
  majorVersion=${composeVersion%%.*}
  dockerPlatform=$(docker version --format '{{.Server.Platform.Name}}' </dev/null 2>/dev/null || true)

  info "Compose version $composeVersion"
  info "Docker: ${dockerPlatform:-unknown}"
}

# --------------------------------------------------------------------------------
# Checks the major version is a number and at least 2
# --------------------------------------------------------------------------------
check_major_version() {
  case "$majorVersion" in
    ''|*[!0-9]*)
      stop_check H-00 "could not read a Compose major version" "got: $composeVersion"
      ;;
  esac

  if [ "$majorVersion" -lt 2 ]; then
    add_problem "install Docker Desktop, which ships Compose v2"
  fi
}

# --------------------------------------------------------------------------------
# Main / Entry Point
# --------------------------------------------------------------------------------
read_versions
check_major_version
report_check H-00 "Compose $composeVersion is older than v2" "Compose $composeVersion is v2 or newer"
