#!/usr/bin/env bash
# ------------------------------------------------------------------------------
# Docker beyond the test sandbox: images, facts about them, old-layout snapshots
# ------------------------------------------------------------------------------
# Sourced by tests/host/lib.sh; runs nothing. Reads RUN and REPO_DIR.
# Removes no image and no container.
# ------------------------------------------------------------------------------

# ------------------------------------------------------------------------------
# build_images LOG_PREFIX [--no-cache]: runs build.sh, logging to the run folder
# ------------------------------------------------------------------------------
# The log is RUN/logs/LOG_PREFIX-images.log.
build_images() {
  local logPrefix=$1
  local cacheFlag=${2:-}
  local logFile="$RUN/logs/$logPrefix-images.log"
  local buildStatus

  if [ "$cacheFlag" = "--no-cache" ]; then
    bash "$REPO_DIR/build.sh" --no-cache >"$logFile" 2>&1 </dev/null
    buildStatus=$?
  else
    bash "$REPO_DIR/build.sh" >"$logFile" 2>&1 </dev/null
    buildStatus=$?
  fi

  if [ "$buildStatus" -ne 0 ]; then
    printf 'Build of sbx-base:local and sbx-claude:local failed. Log: %s\n' "$logFile"
    print_log_tail "$logFile"
    return 1
  fi

  return 0
}

# ------------------------------------------------------------------------------
# expected_arch: the image architecture the daemon should build (or unknown)
# ------------------------------------------------------------------------------
expected_arch() {
  case "$(docker info --format '{{.Architecture}}' </dev/null)" in
    aarch64) printf 'arm64\n' ;;
    x86_64) printf 'amd64\n' ;;
    *) printf 'unknown\n' ;;
  esac
}

# ------------------------------------------------------------------------------
# pin_of NAME: the value of NAME in versions.env; empty when NAME is absent
# ------------------------------------------------------------------------------
pin_of() {
  sed -n "s/^$1=//p" "$REPO_DIR/versions.env" | head -n 1
}

# ------------------------------------------------------------------------------
# claude_pin: the pinned Claude Code version, read from versions.env
# ------------------------------------------------------------------------------
claude_pin() {
  pin_of CLAUDE_CODE_VERSION
}

# ------------------------------------------------------------------------------
# snapshot_old_containers: one sorted line per old container; 1 if ps fails
# ------------------------------------------------------------------------------
# docker ps runs first, so a failed call is a failure, never an empty list.
snapshot_old_containers() {
  local psOutput

  if ! psOutput=$(docker ps -a --format '{{.ID}} {{.Names}} {{.State}}' </dev/null 2>/dev/null); then
    return 1
  fi

  printf '%s\n' "$psOutput" | grep -E '^[0-9a-f]+ cc_' | sort

  return 0
}

# ------------------------------------------------------------------------------
# snapshot_old_folders: old-folder tree hashes and git status; 1 if git fails
# ------------------------------------------------------------------------------
# Tree hashes, not HEAD: a commit made elsewhere during a run changes nothing.
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
