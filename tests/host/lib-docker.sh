#!/usr/bin/env bash
# Docker beyond the test sandbox: building the images, facts about them, and the old-layout containers and folders.
# - Loaded by lib.sh; never run directly. Defines functions only.
# - Reads RUN and REPO_DIR, set by host_init. Removes no image and no container.
# - claude_pin and expected_arch stay shared because the self-test of the host tests calls them through lib.sh.
# - Host side code is stock bash 3.2 with BSD tools (macOS).

# --------------------------------------------------------------------------------
# build_images LOG_PREFIX [--no-cache]: builds sbx-base:local, then sbx-claude:local; logs in the run folder.
# --------------------------------------------------------------------------------
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
      print_log_tail "$logFile"
      return 1
    fi
  done

  return 0
}

# --------------------------------------------------------------------------------
# expected_arch: the image architecture the daemon should produce (arm64, amd64 or unknown).
# --------------------------------------------------------------------------------
expected_arch() {
  case "$(docker info --format '{{.Architecture}}' </dev/null)" in
    aarch64) printf 'arm64\n' ;;
    x86_64) printf 'amd64\n' ;;
    *) printf 'unknown\n' ;;
  esac
}

# --------------------------------------------------------------------------------
# claude_pin: the pinned Claude Code version, read from claude/Dockerfile.
# --------------------------------------------------------------------------------
claude_pin() {
  sed -n 's/^ARG CLAUDE_CODE_VERSION=//p' "$REPO_DIR/claude/Dockerfile"
}

# --------------------------------------------------------------------------------
# snapshot_old_containers: one sorted line per old-layout container: ID, name, state; returns 1 when docker ps fails.
# --------------------------------------------------------------------------------
# docker ps is captured first, so a failed call is a failure and never an empty list.
snapshot_old_containers() {
  local psOutput

  if ! psOutput=$(docker ps -a --format '{{.ID}} {{.Names}} {{.State}}' </dev/null 2>/dev/null); then
    return 1
  fi

  printf '%s\n' "$psOutput" | grep -E '^[0-9a-f]+ cc_' | sort

  return 0
}

# --------------------------------------------------------------------------------
# snapshot_old_folders: the tree hashes of ClaudeCode/ and OpenCode/ at HEAD, then git status of both; returns 1 when git fails.
# --------------------------------------------------------------------------------
# Tree hashes, not HEAD itself: a commit made elsewhere during a run changes nothing here.
snapshot_old_folders() {
  local treeHashes statusOutput

  if ! treeHashes=$(git -C "$REPO_DIR" rev-parse HEAD:ClaudeCode HEAD:OpenCode 2>/dev/null </dev/null); then
    return 1
  fi

  if ! statusOutput=$(git -C "$REPO_DIR" status --porcelain --untracked-files=all -- ClaudeCode OpenCode 2>/dev/null </dev/null); then
    return 1
  fi

  printf '%s\n' "$treeHashes"

  if [ -n "$statusOutput" ]; then
    printf '%s\n' "$statusOutput"
  fi

  return 0
}
