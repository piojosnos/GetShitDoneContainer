#!/usr/bin/env bash
# ------------------------------------------------------------------------------
# Docker beyond the test sandbox: images and facts about them
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
