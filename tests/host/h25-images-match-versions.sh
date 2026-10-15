#!/usr/bin/env bash
# H-25: the images match versions.env, and a build without build.sh stops and names the missing pin.
# - /etc/sbx/versions.env in sbx-claude:local must equal versions.env in the repo, so a forgotten rebuild fails here.
# - gsd-tools runtime-identity in the image must name @opengsd/gsd-core at the pinned version, and
#   ccusage --version must be the pinned version. Claude Code is H-12's.
# - Nothing may sit under /home/sandbox/workspace in the image, because the mount would hide it.
# - base/Dockerfile and claude/Dockerfile are each built once without build.sh, with no build args and
#   no tag, and must stop: the base build naming a missing image pin, the Claude build printing the
#   missing-pin message.
# - The bare build logs go to the run folder.
# Depends on: nothing
# Needs: images built; the run folder (not the running sandbox)
set -u
. "$(dirname "$0")/lib.sh"
host_init

# --------------------------------------------------------------------------------
# FAIL and return 1 when there is no run folder
# --------------------------------------------------------------------------------
require_run_folder() {
  if [ -z "${RUN:-}" ]; then
    fail H-25 "no run folder" "run: bash tests/host/run-all.sh first"
    return 1
  fi
}

# --------------------------------------------------------------------------------
# Checks the record in the Claude image equals versions.env in the repo
# --------------------------------------------------------------------------------
check_record() {
  local recordFile="$RUN/logs/h25-image-versions.env"
  local diffText

  run_timeout 60 docker run --rm --entrypoint cat sbx-claude:local /etc/sbx/versions.env </dev/null >"$recordFile" 2>&1

  diffText=$(diff "$recordFile" "$REPO_DIR/versions.env" 2>&1)
  if [ -n "$diffText" ]; then
    add_problem "/etc/sbx/versions.env in sbx-claude:local differs from versions.env; rebuild with ./build.sh: $(first_lines "$diffText")"
  fi
}

# --------------------------------------------------------------------------------
# Checks the GSD and ccusage in the Claude image are the pinned versions
# --------------------------------------------------------------------------------
check_tool_versions() {
  local gsdPin ccusagePin gsdIdentity ccusageVersion

  gsdPin=$(pin_of GSD_CORE_VERSION)
  ccusagePin=$(pin_of CCUSAGE_VERSION)

  gsdIdentity=$(run_timeout 60 docker run --rm --entrypoint gsd-tools sbx-claude:local runtime-identity --raw </dev/null 2>&1)
  if [ "$gsdIdentity" != "{\"packageName\":\"@opengsd/gsd-core\",\"version\":\"$gsdPin\"}" ]; then
    add_problem "the image's GSD is $(first_lines "$gsdIdentity"); versions.env pins $gsdPin"
  fi

  ccusageVersion=$(run_timeout 60 docker run --rm --entrypoint ccusage sbx-claude:local --version </dev/null 2>&1)
  if [ "$ccusageVersion" != "ccusage $ccusagePin" ]; then
    add_problem "the image's ccusage is $(first_lines "$ccusageVersion"); versions.env pins $ccusagePin"
  fi
}

# --------------------------------------------------------------------------------
# Checks nothing sits under /home/sandbox/workspace in the Claude image
# --------------------------------------------------------------------------------
check_workspace_empty() {
  local listing listingStatus

  listing=$(run_timeout 60 docker run --rm --entrypoint ls sbx-claude:local -A /home/sandbox/workspace </dev/null 2>&1)
  listingStatus=$?

  if [ "$listingStatus" -ne 0 ]; then
    add_problem "could not list /home/sandbox/workspace in the image (exit $listingStatus): $(first_lines "$listing")"
  elif [ -n "$listing" ]; then
    add_problem "the image holds files under /home/sandbox/workspace, which the mount hides: $(first_lines "$listing")"
  fi
}

# --------------------------------------------------------------------------------
# Checks both Dockerfiles stop when built without build.sh, with the message that names the missing pin
# --------------------------------------------------------------------------------
# - The base build stops while it reads the FROM lines; which FROM pin BuildKit names first is not documented, so any of them is accepted.
# - The plain progress log also echoes the RUN command and the FROM lines, so the checks match only what BuildKit and the shell print when the guard fires, never the Dockerfile text: the "should not be blank" error of the empty FROM, and the shell's own "NAME: NAME is not set" line.
check_bare_builds() {
  local baseLog="$RUN/logs/h25-bare-base.log"
  local claudeLog="$RUN/logs/h25-bare-claude.log"
  local baseStatus claudeStatus

  run_timeout 300 docker build --progress=plain -f "$REPO_DIR/base/Dockerfile" "$REPO_DIR" </dev/null >"$baseLog" 2>&1
  baseStatus=$?

  if [ "$baseStatus" -eq 0 ] || ! grep -Eq 'base name \(.*(TEMURIN_IMAGE|UV_IMAGE|UBUNTU_IMAGE|SHELLCHECK_IMAGE|HADOLINT_IMAGE).*\) should not be blank' "$baseLog"; then
    add_problem "a build of base/Dockerfile without build.sh did not stop naming a missing pin; log: $baseLog"
  fi

  run_timeout 300 docker build --progress=plain -f "$REPO_DIR/claude/Dockerfile" "$REPO_DIR" </dev/null >"$claudeLog" 2>&1
  claudeStatus=$?

  if [ "$claudeStatus" -eq 0 ] || ! grep -Fq 'CLAUDE_CODE_VERSION: CLAUDE_CODE_VERSION is not set; build with ./build.sh' "$claudeLog"; then
    add_problem "a build of claude/Dockerfile without build.sh did not stop with the missing-pin message; log: $claudeLog"
  fi
}

# --------------------------------------------------------------------------------
# Main / Entry Point
# --------------------------------------------------------------------------------
require_no_arguments "$@" || exit 2
require_run_folder || exit 1
check_record
check_tool_versions
check_workspace_empty
check_bare_builds
report_check H-25 "an image does not match versions.env, or a build without build.sh did not stop" \
  "the images match versions.env (GSD $(pin_of GSD_CORE_VERSION), ccusage $(pin_of CCUSAGE_VERSION)), nothing sits under the mount point, and a build without build.sh stops naming the missing pin"
