#!/usr/bin/env bash
# Docker beyond the test sandbox: building the images, facts about them, and the old-layout containers.
# - Loaded by lib.sh; never run directly. Defines functions only.
# - Reads RUN and REPO_DIR, set by host_init. Removes no image and no container.
# - claude_pin and expected_arch stay shared because the self-test of the host tests calls them through lib.sh.
# - Host side code is stock bash 3.2 with BSD tools (macOS).

# build_images LOG_PREFIX [--no-cache]: builds sbx-base:local, then sbx-claude:local; logs in the run folder.
build_images() {
  local logPrefix=$1
  local cacheFlag=${2:-}
  local imageName logFile buildStatus

  for imageName in base claude; do
    logFile="$RUN/logs/$logPrefix-$imageName.log"
    if [ "$cacheFlag" = "--no-cache" ]; then
      docker build --no-cache -f "$REPO_DIR/$imageName/Dockerfile" -t "sbx-$imageName:local" "$REPO_DIR" >"$logFile" 2>&1 </dev/null
      buildStatus=$?
    else
      docker build -f "$REPO_DIR/$imageName/Dockerfile" -t "sbx-$imageName:local" "$REPO_DIR" >"$logFile" 2>&1 </dev/null
      buildStatus=$?
    fi

    if [ "$buildStatus" -ne 0 ]; then
      printf 'Build of sbx-%s:local failed. Log: %s\n' "$imageName" "$logFile"
      tail -n 20 "$logFile" | sed 's/^/    /'
      return 1
    fi
  done

  return 0
}

# expected_arch: the image architecture the daemon should produce (arm64, amd64 or unknown).
expected_arch() {
  case "$(docker info --format '{{.Architecture}}' </dev/null)" in
    aarch64) printf 'arm64\n' ;;
    x86_64) printf 'amd64\n' ;;
    *) printf 'unknown\n' ;;
  esac
}

# claude_pin: the pinned Claude Code version, read from claude/Dockerfile.
claude_pin() {
  sed -n 's/^ARG CLAUDE_CODE_VERSION=//p' "$REPO_DIR/claude/Dockerfile"
}

# snapshot_old_containers: one sorted line per old-layout container: ID, name, state.
snapshot_old_containers() {
  docker ps -a --format '{{.ID}} {{.Names}} {{.State}}' </dev/null 2>/dev/null | grep -E '^[0-9a-f]+ cc_' | sort
}
