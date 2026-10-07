#!/usr/bin/env bash
# Self-test of H-09 (tests/host/h09-rebuild-keeps-files-no-volumes.sh) against the fake docker: a rebuild that keeps the sentinels, the volumes and the one bind mount passes; a second mount, a changed volume list and deleted memories fail.
# - Run by run-all.sh; runs alone too.
# - Makes one work folder under TMPDIR and removes only that folder at exit.
# - Usage, from anywhere: bash tests/selftest/host/h09-rebuild-keeps-files-no-volumes.sh   (exit 0 = every case passes)
set -u
. "$(dirname "$0")/lib.sh"

# --------------------------------------------------------------------------------
# Cases of H-09, each run alone against the fake docker
# --------------------------------------------------------------------------------
case_h09_alone() {
  echo "--- H-09 on its own"
  reset_state
  make_fixture_run
  run_standalone "$WORK/out.h09" h09-rebuild-keeps-files-no-volumes.sh FAKE_VOLUMES="olddata"
  expect "H-09: sentinels, volumes and the one bind mount pass" equals "$CHECK_RC" "0"
  expect "H-09: prints PASS: H-09" has_text "$WORK/out.h09" "PASS: H-09"
  sed 's/^.*ARGS: //' "$FAKE_LOG" >"$WORK/args.h09"
  expect "H-09: both images are rebuilt" equals "$(grep -c '^build ' "$WORK/args.h09")" "2"
  expect "H-09: the rebuild uses the cache by default" lacks_text "$WORK/args.h09" "--no-cache"
  expect "H-09: the sandbox is up again" test -f "$WORK/state/container"
  reset_state
  make_fixture_run
  run_standalone "$WORK/out.h09.mount" h09-rebuild-keeps-files-no-volumes.sh FAKE_EXTRA_MOUNT=1
  expect "H-09: a second mount fails" equals "$CHECK_RC" "1"
  expect "H-09: the second mount is shown" has_text "$WORK/out.h09.mount" "/home/sandbox/extra"
  reset_state
  make_fixture_run
  run_standalone "$WORK/out.h09.vol" h09-rebuild-keeps-files-no-volumes.sh FAKE_VOLUMES="a" FAKE_VOLUMES_AFTER_BUILD="a b"
  expect "H-09: a changed volume list fails" equals "$CHECK_RC" "1"
  expect "H-09: the volume change is reported" has_text "$WORK/out.h09.vol" "volume"
  reset_state
  make_fixture_run
  run_standalone "$WORK/out.h09.nocache" h09-rebuild-keeps-files-no-volumes.sh SBXTEST_NO_CACHE=1
  sed 's/^.*ARGS: //' "$FAKE_LOG" >"$WORK/args.h09.nocache"
  expect "H-09: SBXTEST_NO_CACHE=1 still passes" equals "$CHECK_RC" "0"
  expect "H-09: SBXTEST_NO_CACHE=1 adds --no-cache to both builds" \
    equals "$(grep -c '^build --no-cache ' "$WORK/args.h09.nocache")" "2"
  expect "H-09: the memory sentinel survives" \
    test -f "$FIXTURE/state/claude/projects/-home-sandbox-workspace-hosttest/memory/h09-memory.md"
  reset_state
  make_fixture_run
  run_standalone "$WORK/out.h09.clobber" h09-rebuild-keeps-files-no-volumes.sh FAKE_SYNC_CLOBBERS=1
  expect "H-09: a restart that deletes the memories fails" equals "$CHECK_RC" "1"
  expect "H-09: the lost memory is named" has_text "$WORK/out.h09.clobber" "h09-memory.md"
}

# --------------------------------------------------------------------------------
# Cases of H-09 for the volume list: other projects' volumes are ignored
# --------------------------------------------------------------------------------
case_h09_volume_scope() {
  echo "--- H-09 volume list"
  reset_state
  make_fixture_run
  run_standalone "$WORK/out.h09.other" h09-rebuild-keeps-files-no-volumes.sh FAKE_VOLUMES="olddata" FAKE_UNRELATED_VOLUMES_AFTER_BUILD="other_cache"
  expect "H-09: a volume made by something else during the rebuild does not fail" equals "$CHECK_RC" "0"
  sed 's/^.*ARGS: //' "$FAKE_LOG" >"$WORK/args.h09.scope"
  expect "H-09: the volume list is scoped to the test project" \
    has_text "$WORK/args.h09.scope" "volume ls -q --filter label=com.docker.compose.project=sbx-hosttest"
}

# --------------------------------------------------------------------------------
# Main / Entry Point
# --------------------------------------------------------------------------------
require_no_arguments "$@" || exit 2
start_group || exit 1
case_h09_alone
case_h09_volume_scope
finish_cases
