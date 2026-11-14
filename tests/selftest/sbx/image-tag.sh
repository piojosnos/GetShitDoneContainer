#!/usr/bin/env bash
# ------------------------------------------------------------------------------
# Self-test of SBX_IMAGE_TAG: it picks the image names; only local, test pass
# ------------------------------------------------------------------------------
# Usage: bash tests/selftest/sbx/image-tag.sh (exit 0 = all pass)
# Run by run-all.sh; its one work folder under TMPDIR is removed at exit.
# No case reaches a Docker daemon: build.sh runs without docker on its PATH.
# ------------------------------------------------------------------------------
set -u
. "$(dirname "$0")/lib.sh"

# ------------------------------------------------------------------------------
# tag_refused LABEL NAME PATH: the tag text, nothing made, no build started
# ------------------------------------------------------------------------------
tag_refused() {
  refused_cleanly "$1" "SBX_IMAGE_TAG must be local or test, not 'latest'" "$2" "$3" || return 1
  lacks_text "$WORK/$1.out" "build.sh: building" || return 1
  lacks_text "$WORK/$1.err" "build.sh: building"
}

# ------------------------------------------------------------------------------
# run_build_without_docker LABEL: runs build.sh with no docker on the PATH
# ------------------------------------------------------------------------------
# The run stops at the first docker call and never reaches a daemon, whatever
# the Mac's Docker or buildx set-up. It adds no stand-in. Only dirname and grep
# are linked, the two tools build.sh needs before its first build. Paths come
# from type -P, so a shell function named grep in the caller does not matter.
# Output goes to WORK/LABEL.out and WORK/LABEL.err; BUILD_RC holds the status.
# ------------------------------------------------------------------------------
run_build_without_docker() {
  local bashPath
  local pathDir=$WORK/no-docker-path

  bashPath=$(type -P bash)

  mkdir -p "$pathDir"
  ln -sf "$(type -P dirname)" "$pathDir/dirname"
  ln -sf "$(type -P grep)" "$pathDir/grep"

  PATH="$pathDir" "$bashPath" "$REPO/build.sh" >"$WORK/$1.out" 2>"$WORK/$1.err" </dev/null
  BUILD_RC=$?
}

# ------------------------------------------------------------------------------
# build_refused LABEL: exit 1, the tag text in the error, no build started
# ------------------------------------------------------------------------------
build_refused() {
  [ "$BUILD_RC" -eq 1 ] || return 1
  has_text "$WORK/$1.err" "build.sh: SBX_IMAGE_TAG must be local or test, not 'latest'" || return 1
  lacks_text "$WORK/$1.out" "build.sh: building"
}

# ------------------------------------------------------------------------------
# Case: the tag picks the image name; an empty value means local
# ------------------------------------------------------------------------------
case_tag_picks_the_image() {
  local readText='read_registry_entry NAME; printf "%s\n" "$agentImage"'
  local readOut

  SBX_CONFIG_DIR=$WORK/cfg-tag-image
  export SBX_CONFIG_DIR

  echo '--- the tag picks the image'

  plant_entry entry1 "SBX_DIR=/x/one" "SBX_AGENT=cursor"
  plant_entry entry2 "SBX_DIR=/x/two" "SBX_AGENT=claude"

  readOut=$(export SBX_IMAGE_TAG=test; lib_eval "${readText/NAME/entry1}" 2>&1)
  expect "image tag: test maps a cursor entry to sbx-cursor:test" equals "$readOut" "sbx-cursor:test"

  readOut=$(export SBX_IMAGE_TAG=test; lib_eval "${readText/NAME/entry2}" 2>&1)
  expect "image tag: test maps a claude entry to sbx-claude:test" equals "$readOut" "sbx-claude:test"

  readOut=$(export SBX_IMAGE_TAG=; lib_eval "${readText/NAME/entry1}" 2>&1)
  expect "image tag: an empty value means local" equals "$readOut" "sbx-cursor:local"
}

# ------------------------------------------------------------------------------
# Case: every sbx-* script refuses another tag before it does anything
# ------------------------------------------------------------------------------
case_tag_refusals() {
  local scriptFile

  SBX_CONFIG_DIR=$WORK/cfg-tag-refusals
  export SBX_CONFIG_DIR

  echo '--- other tags are refused'

  export SBX_IMAGE_TAG=latest

  run_sbx tagadd sbx-add name1 "$WORK/tag dir/one"
  expect "image tag: sbx-add refuses latest and makes nothing" tag_refused tagadd name1 "$WORK/tag dir/one"

  run_sbx taglist sbx-list
  expect "image tag: sbx-list refuses latest" tag_refused taglist "" ""

  for scriptFile in sbx-fix-modes sbx-rm sbx-shell sbx-start sbx-stop sbx-upgrade; do
    run_sbx "tag-$scriptFile" "$scriptFile" name1
    expect "image tag: $scriptFile refuses latest before anything else" tag_refused "tag-$scriptFile" name1 ""
  done

  unset SBX_IMAGE_TAG
}

# ------------------------------------------------------------------------------
# Case: build.sh names its first image by the tag and refuses another tag
# ------------------------------------------------------------------------------
case_build_tag() {
  echo '--- build.sh and the tag'

  unset SBX_IMAGE_TAG
  run_build_without_docker buildunset
  expect "image tag: build.sh builds sbx-base:local when the tag is unset" equals "$(cat "$WORK/buildunset.out")" "build.sh: building sbx-base:local"

  export SBX_IMAGE_TAG=
  run_build_without_docker buildempty
  expect "image tag: build.sh builds sbx-base:local when the tag is empty" equals "$(cat "$WORK/buildempty.out")" "build.sh: building sbx-base:local"

  export SBX_IMAGE_TAG=test
  run_build_without_docker buildtest
  expect "image tag: build.sh builds sbx-base:test for test" equals "$(cat "$WORK/buildtest.out")" "build.sh: building sbx-base:test"

  export SBX_IMAGE_TAG=latest
  run_build_without_docker buildbad
  expect "image tag: build.sh refuses latest before any build" build_refused buildbad

  unset SBX_IMAGE_TAG
}

# ------------------------------------------------------------------------------
# Main / Entry Point
# ------------------------------------------------------------------------------
require_no_arguments "$@" || exit 2
start_group || exit 1
case_tag_picks_the_image
case_tag_refusals
case_build_tag
finish_cases
