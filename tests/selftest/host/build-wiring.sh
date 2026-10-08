#!/usr/bin/env bash
# Self-test of build.sh against the fake docker: both builds in order, every pin passed to both with its value from versions.env, extra arguments, any folder, and a stop on a missing or empty versions.env.
# - Run by run-all.sh; runs alone too.
# - Makes one work folder under TMPDIR and removes only that folder at exit.
# - Usage, from anywhere: bash tests/selftest/host/build-wiring.sh   (exit 0 = every case passes)
set -u
. "$(dirname "$0")/lib.sh"

# --------------------------------------------------------------------------------
# run_build OUTFILE SCRIPT [ARG...]: runs bash SCRIPT ARG... with stdin closed and all output in OUTFILE; sets BUILD_RC.
# --------------------------------------------------------------------------------
run_build() {
  local outFile=$1
  local script=$2

  shift 2
  BUILD_RC=0
  bash "$script" "$@" >"$outFile" 2>&1 </dev/null || BUILD_RC=$?
}

# --------------------------------------------------------------------------------
# copy_build_script DIR: makes DIR and copies build.sh into it.
# --------------------------------------------------------------------------------
copy_build_script() {
  mkdir -p "$1"
  cp "$REPO/build.sh" "$1/build.sh"
}

# --------------------------------------------------------------------------------
# build_lines: the docker build calls in the fake docker log, without the prefix up to ARGS: .
# --------------------------------------------------------------------------------
build_lines() {
  sed -n 's/^.*ARGS: //p' "$FAKE_LOG" | grep '^build '
}

# --------------------------------------------------------------------------------
# build_line_count: how many docker build calls the fake docker log holds.
# --------------------------------------------------------------------------------
build_line_count() {
  sed -n 's/^.*ARGS: //p' "$FAKE_LOG" | grep -c '^build '
}

# --------------------------------------------------------------------------------
# tag_of LINE: the image tag after -t in a docker build call.
# --------------------------------------------------------------------------------
tag_of() {
  printf '%s\n' "$1" | sed -n 's/.* -t \([^ ]*\) .*/\1/p'
}

# --------------------------------------------------------------------------------
# pin_names_in FILE: the names set in a versions.env file, one per line.
# --------------------------------------------------------------------------------
pin_names_in() {
  grep -oE '^[A-Z_]+' "$1"
}

# --------------------------------------------------------------------------------
# stopped_before_build OUTFILE TEXT: true if the last build run failed, printed TEXT and made no docker build call.
# --------------------------------------------------------------------------------
stopped_before_build() {
  [ "$BUILD_RC" -ne 0 ] && has_text "$1" "$2" && [ "$(build_line_count)" -eq 0 ]
}

# --------------------------------------------------------------------------------
# Cases of build.sh run from the repo root
# --------------------------------------------------------------------------------
case_build_from_repo_root() {
  local buildLineText firstLine secondLine pinName pinValue missingText

  echo "--- build.sh from the repo root"
  reset_state
  run_build "$WORK/out.build" "$REPO/build.sh"
  buildLineText=$(build_lines)
  firstLine=$(printf '%s\n' "$buildLineText" | sed -n 1p)
  secondLine=$(printf '%s\n' "$buildLineText" | sed -n 2p)

  expect "build.sh: builds sbx-base:local, then sbx-claude:local" \
    equals "$BUILD_RC $(build_line_count) $(tag_of "$firstLine") $(tag_of "$secondLine")" "0 2 sbx-base:local sbx-claude:local"

  missingText=""

  for pinName in $(pin_names_in "$REPO/versions.env"); do
    if ! string_matches " --build-arg $pinName -" "$firstLine" || ! string_matches " --build-arg $pinName -" "$secondLine"; then
      missingText="$missingText $pinName"
    fi
  done

  expect "build.sh: passes every versions.env name to both builds as a bare --build-arg" equals "$missingText" ""

  missingText=""

  for pinName in $(pin_names_in "$REPO/versions.env"); do
    pinValue=$(sed -n "s/^$pinName=//p" "$REPO/versions.env")

    if ! grep -Fxq "sbx-base:local $pinName=$pinValue" "$WORK/state/build-args.log" \
      || ! grep -Fxq "sbx-claude:local $pinName=$pinValue" "$WORK/state/build-args.log"; then
      missingText="$missingText $pinName"
    fi
  done

  expect "build.sh: Docker sees each pin's value from versions.env" equals "$missingText" ""

  reset_state
  run_build "$WORK/out.extra" "$REPO/build.sh" --no-cache --pull

  expect "build.sh: extra arguments reach both builds" \
    equals "$BUILD_RC $(build_lines | grep -c '^build --no-cache --pull -f ')" "0 2"
}

# --------------------------------------------------------------------------------
# Cases of build.sh run from another folder, with a caller's environment, and with an added pin
# --------------------------------------------------------------------------------
case_build_elsewhere() {
  local newPinOk pinValue

  echo "--- build.sh from another folder"
  reset_state
  cd "$WORK" || return 1
  run_build "$WORK/out.elsewhere" "$REPO/build.sh"
  cd "$REPO" || return 1

  expect "build.sh: runs from any folder with the repo root as context" \
    equals "$BUILD_RC $(grep ' context=' "$WORK/state/build-args.log" | tr '\n' ' ')" "0 sbx-base:local context=$REPO sbx-claude:local context=$REPO "

  reset_state
  NODE_VERSION=0.0.1 run_build "$WORK/out.callerenv" "$REPO/build.sh"
  pinValue=$(sed -n 's/^NODE_VERSION=//p' "$REPO/versions.env")

  expect "build.sh: a caller's environment never overrides a pin" \
    equals "$BUILD_RC $(grep -c '^sbx-.*:local NODE_VERSION='"$pinValue"'$' "$WORK/state/build-args.log") $(grep -c '0\.0\.1' "$WORK/state/build-args.log")" "0 2 0"

  reset_state
  copy_build_script "$WORK/newpin"
  cp "$REPO/versions.env" "$WORK/newpin/versions.env"
  printf 'NEW_TOOL_VERSION=1.2.3\n' >>"$WORK/newpin/versions.env"
  run_build "$WORK/out.newpin" "$WORK/newpin/build.sh"
  newPinOk=0

  if grep -Fxq "sbx-base:local NEW_TOOL_VERSION=1.2.3" "$WORK/state/build-args.log" \
    && grep -Fxq "sbx-claude:local NEW_TOOL_VERSION=1.2.3" "$WORK/state/build-args.log"; then
    newPinOk=1
  fi

  expect "build.sh: a new pin reaches both builds with no change to build.sh" equals "$BUILD_RC $newPinOk" "0 1"
}

# --------------------------------------------------------------------------------
# Cases where build.sh stops: no versions.env, no pins, a failed base build
# --------------------------------------------------------------------------------
case_build_stops() {
  echo "--- build.sh stops"
  reset_state
  copy_build_script "$WORK/nopins"
  run_build "$WORK/out.nofile" "$WORK/nopins/build.sh"

  expect "build.sh: a missing versions.env stops before any build" stopped_before_build "$WORK/out.nofile" "versions.env is missing"

  reset_state
  copy_build_script "$WORK/emptypins"
  printf '# a comment and no pins\n' >"$WORK/emptypins/versions.env"
  run_build "$WORK/out.emptyfile" "$WORK/emptypins/build.sh"

  expect "build.sh: a versions.env without pins stops before any build" stopped_before_build "$WORK/out.emptyfile" "holds no pins"

  reset_state
  FAKE_BUILD_FAIL=sbx-base:local run_build "$WORK/out.basefail" "$REPO/build.sh"

  expect "build.sh: a failed base build stops before the claude build" \
    equals "$([ "$BUILD_RC" -ne 0 ] && echo failed) $(build_line_count)" "failed 1"
}

# --------------------------------------------------------------------------------
# Main / Entry Point
# --------------------------------------------------------------------------------
require_no_arguments "$@" || exit 2
start_group || exit 1
case_build_from_repo_root
case_build_elsewhere
case_build_stops
finish_cases
