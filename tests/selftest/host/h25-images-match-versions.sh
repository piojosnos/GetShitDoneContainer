#!/usr/bin/env bash
# Self-test of H-25 (tests/host/h25-images-match-versions.sh) against the fake docker: images that match versions.env pass; a stale record, a GSD or ccusage that is not the pin, files under the mount point, a build that does not stop without build.sh and a missing run folder each fail.
# - Run by run-all.sh; runs alone too.
# - Makes one work folder under TMPDIR and removes only that folder at exit.
# - Usage, from anywhere: bash tests/selftest/host/h25-images-match-versions.sh   (exit 0 = every case passes)
set -u
. "$(dirname "$0")/lib.sh"

# --------------------------------------------------------------------------------
# Cases of H-25, each run alone against the fake docker
# --------------------------------------------------------------------------------
case_h25_alone() {
  echo "--- H-25 on its own"
  reset_state
  make_fixture_run
  run_standalone "$WORK/out.h25" h25-images-match-versions.sh
  expect "H-25: images that match versions.env pass" equals "$CHECK_RC" "0"
  expect "H-25: prints PASS: H-25" has_text "$WORK/out.h25" "PASS: H-25"
  expect "H-25: the record read from the image is kept in the run folder" test -s "$FIXTURE/logs/h25-image-versions.env"
  expect "H-25: the bare base build log is kept in the run folder" test -s "$FIXTURE/logs/h25-bare-base.log"
  expect "H-25: the bare Claude build log is kept in the run folder" test -s "$FIXTURE/logs/h25-bare-claude.log"
  sed 's/^.*ARGS: //' "$FAKE_LOG" >"$WORK/args.h25"
  expect "H-25: the record is read from the Claude image" \
    equals "$(grep -c '^run --rm --entrypoint cat sbx-claude:local /etc/sbx/versions.env$' "$WORK/args.h25")" "1"
  expect "H-25: both bare builds run without build args and without a tag" \
    equals "$(grep -c '^build --progress=plain -f ' "$WORK/args.h25") $(grep '^build --progress=plain' "$WORK/args.h25" | grep -cE -- '--build-arg| -t ')" "2 0"
  expect "H-25: one bare build is the base Dockerfile and one the Claude Dockerfile" \
    equals "$(grep -c '^build --progress=plain -f .*/base/Dockerfile ' "$WORK/args.h25") $(grep -c '^build --progress=plain -f .*/claude/Dockerfile ' "$WORK/args.h25")" "1 1"
  expect "H-25: a bare build is not counted as a build of the images" test ! -e "$WORK/state/built"
  run_standalone "$WORK/out.h25.stale" h25-images-match-versions.sh FAKE_RECORD_STALE=1
  expect "H-25: a stale record fails" failed_with "$CHECK_RC" "$WORK/out.h25.stale" "differs from versions.env"
  run_standalone "$WORK/out.h25.gsd" h25-images-match-versions.sh FAKE_GSD_IDENTITY=0.0.0
  expect "H-25: a GSD that is not the pin fails" failed_with "$CHECK_RC" "$WORK/out.h25.gsd" "the image's GSD"
  run_standalone "$WORK/out.h25.ccusage" h25-images-match-versions.sh FAKE_CCUSAGE_VERSION=0.0.0
  expect "H-25: a ccusage that is not the pin fails" failed_with "$CHECK_RC" "$WORK/out.h25.ccusage" "the image's ccusage"
  run_standalone "$WORK/out.h25.baked" h25-images-match-versions.sh FAKE_WORKSPACE_BAKED=state
  expect "H-25: files under the mount point fail" failed_with "$CHECK_RC" "$WORK/out.h25.baked" "/home/sandbox/workspace"
  run_standalone "$WORK/out.h25.bare" h25-images-match-versions.sh FAKE_BARE_BUILD_OK=1
  expect "H-25: a build that does not stop without build.sh fails" failed_with "$CHECK_RC" "$WORK/out.h25.bare" "without build.sh did not stop"
  reset_state
  FIXTURE=""
  run_standalone "$WORK/out.h25.none" h25-images-match-versions.sh
  expect "H-25: no run folder fails" failed_with "$CHECK_RC" "$WORK/out.h25.none" "no run folder"
}

# --------------------------------------------------------------------------------
# Main / Entry Point
# --------------------------------------------------------------------------------
require_no_arguments "$@" || exit 2
start_group || exit 1
case_h25_alone
finish_cases
