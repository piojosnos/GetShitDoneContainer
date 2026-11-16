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
# The log is RUN/logs/LOG_PREFIX-images.log. build.sh reads SBX_IMAGE_TAG, which
# host_init sets to test, so it builds the test images.
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
    printf 'Build of the sbx images failed. Log: %s\n' "$logFile"
    print_log_tail "$logFile"
    return 1
  fi

  return 0
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
# test_root_ca_file: the throwaway root certificate the test images trust
# ------------------------------------------------------------------------------
# Kept outside the run folder and reused, so the test images keep their build
# cache; clean.sh removes it with the run folders.
# ------------------------------------------------------------------------------
test_root_ca_file() {
  local baseDir

  baseDir=${TMPDIR:-/tmp}
  baseDir=${baseDir%/}

  if [ -z "$baseDir" ]; then
    baseDir=/tmp
  fi

  printf '%s/sbx-hosttest-root-ca/root-ca.pem\n' "$baseDir"
}

# ------------------------------------------------------------------------------
# cert_fingerprint FILE: SHA-256 fingerprint of FILE, uppercase hex, no colons
# ------------------------------------------------------------------------------
# Only the text after the equals sign is read, since LibreSSL and OpenSSL word
# the prefix differently. Prints nothing for a missing or invalid file.
# ------------------------------------------------------------------------------
cert_fingerprint() {
  openssl x509 -noout -fingerprint -sha256 -in "$1" 2>/dev/null </dev/null | sed 's/^[^=]*=//' | tr -d ':' | tr 'a-f' 'A-F'
}
