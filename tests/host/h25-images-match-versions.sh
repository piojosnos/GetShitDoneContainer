#!/usr/bin/env bash
# ------------------------------------------------------------------------------
# H-25: the images match versions.env; a bare build is refused
# ------------------------------------------------------------------------------
# Needs: images built; the run folder (not the running sandbox)
# The tools are sbx-selfcheck's (H-34); a build without build.sh must name the missing pin.
# ------------------------------------------------------------------------------
set -u
. "$(dirname "$0")/lib.sh"
host_init

# ------------------------------------------------------------------------------
# FAIL and return 1 when there is no run folder
# ------------------------------------------------------------------------------
require_run_folder() {
  if [ -z "${RUN:-}" ]; then
    fail H-25 "no run folder" "run: bash tests/host/run-all.sh first"
    return 1
  fi
}

# ------------------------------------------------------------------------------
# Checks the record in the Claude image equals versions.env in the repo
# ------------------------------------------------------------------------------
# A forgotten rebuild fails here.
# ------------------------------------------------------------------------------
check_record() {
  local recordFile="$RUN/logs/h25-image-versions.env"
  local diffText

  run_timeout 60 docker run --rm --entrypoint cat "$CLAUDE_IMAGE" /etc/sbx/versions.env </dev/null >"$recordFile" 2>&1

  diffText=$(diff "$recordFile" "$REPO_DIR/versions.env" 2>&1)
  if [ -n "$diffText" ]; then
    add_problem "/etc/sbx/versions.env in $CLAUDE_IMAGE differs from versions.env; rerun ./host-test.sh (it rebuilds the test images): $(first_lines "$diffText")"
  fi
}

# ------------------------------------------------------------------------------
# Checks both Dockerfiles stop when built without build.sh, naming the pin
# ------------------------------------------------------------------------------
# BuildKit names whichever blank FROM pin it reads first, so any is accepted.
# Only the guard's own messages count, never the echoed Dockerfile text.
# The Claude build gets the test base image: BASE_IMAGE is not a pin, and its
# Dockerfile default names an image a test run must not use (or may lack).
# ------------------------------------------------------------------------------
check_bare_builds() {
  local baseLog="$RUN/logs/h25-bare-base.log"
  local claudeLog="$RUN/logs/h25-bare-claude.log"
  local baseStatus claudeStatus

  run_timeout 300 docker build --progress=plain -f "$REPO_DIR/base/Dockerfile" "$REPO_DIR" </dev/null >"$baseLog" 2>&1
  baseStatus=$?

  if [ "$baseStatus" -eq 0 ] || ! grep -Eq 'base name \(.*(TEMURIN_IMAGE|UV_IMAGE|UBUNTU_IMAGE|SHELLCHECK_IMAGE|HADOLINT_IMAGE).*\) should not be blank' "$baseLog"; then
    add_problem "a build of base/Dockerfile without build.sh did not stop naming a missing pin; log: $baseLog"
  fi

  run_timeout 300 docker build --progress=plain --build-arg "BASE_IMAGE=$BASE_IMAGE" -f "$REPO_DIR/claude/Dockerfile" "$REPO_DIR" </dev/null >"$claudeLog" 2>&1
  claudeStatus=$?

  if [ "$claudeStatus" -eq 0 ] || ! grep -Fq 'CLAUDE_CODE_VERSION: CLAUDE_CODE_VERSION is not set; build with ./build.sh' "$claudeLog"; then
    add_problem "a build of claude/Dockerfile without build.sh did not stop with the missing-pin message; log: $claudeLog"
  fi
}

# ------------------------------------------------------------------------------
# Main / Entry Point
# ------------------------------------------------------------------------------
require_no_arguments "$@" || exit 2
require_run_folder || exit 1
check_record
check_bare_builds
report_check H-25 "the image's versions.env differs from the repo's, or a build without build.sh did not stop" \
  "the Claude test image's versions.env equals the repo's, and a build without build.sh stops naming the missing pin"
