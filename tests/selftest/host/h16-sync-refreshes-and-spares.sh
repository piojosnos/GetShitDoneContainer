#!/usr/bin/env bash
# Self-test of H-16 (tests/host/h16-sync-refreshes-and-spares.sh) against the fake docker: a restart that refreshes the bundle and GSD and spares user files passes; a hook that never ran, one that deletes user skills, a GSD sync that drops the user's settings and a sandbox where GSD never synced fail.
# - Run by run-all.sh; runs alone too.
# - Makes one work folder under TMPDIR and removes only that folder at exit.
# - Usage, from anywhere: bash tests/selftest/host/h16-sync-refreshes-and-spares.sh   (exit 0 = every case passes)
set -u
. "$(dirname "$0")/lib.sh"

# --------------------------------------------------------------------------------
# Cases of H-16, each run alone against the fake docker
# --------------------------------------------------------------------------------
case_h16_alone() {
  echo "--- H-16 on its own"
  reset_state
  make_fixture_run
  fake_start_sync "$FIXTURE"
  run_standalone "$WORK/out.h16" h16-sync-refreshes-and-spares.sh
  expect "H-16: a restart that refreshes the bundle and spares user files passes" equals "$CHECK_RC" "0"
  expect "H-16: prints PASS: H-16" has_text "$WORK/out.h16" "PASS: H-16"
  expect "H-16: the stale rule is gone" test ! -e "$FIXTURE/state/claude/rules/h16-stale.md"
  expect "H-16: the old bundle skill is gone" test ! -e "$FIXTURE/state/claude/skills/h16-old-bundle-skill"
  expect "H-16: the user skill keeps its sentinel" has_text "$FIXTURE/state/claude/skills/h16-user-skill/SKILL.md" "h16-"
  expect "H-16: GSD is back at the pin" equals "$(cat "$FIXTURE/state/claude/gsd-core/VERSION")" "$(pin_of GSD_CORE_VERSION)"
  expect "H-16: the hand-edited GSD skill is restored" lacks_text "$FIXTURE/state/claude/skills/gsd-fake-skill/SKILL.md" "h16 hand edit"
  expect "H-16: the settings key survives" has_text "$FIXTURE/state/claude/settings.json" "h16-"
  expect "H-16: the session transcript survives" \
    has_text "$FIXTURE/state/claude/projects/-home-sandbox-workspace-hosttest/h16-session.jsonl" "h16-"
  expect "H-16: the memory keeps its sentinel" \
    has_text "$FIXTURE/state/claude/projects/-home-sandbox-workspace-hosttest/memory/h16-memory.md" "h16-"
  expect "H-16: CLAUDE.md keeps its sentinel" has_text "$FIXTURE/state/claude/CLAUDE.md" "h16-"
  expect "H-16: rules equal the repo again" diff -r -q "$REPO/best-practices/rules" "$FIXTURE/state/claude/rules"
  expect "H-16: the edited bundle skill equals the repo again" \
    diff -r -q "$REPO/best-practices/skills/merged" "$FIXTURE/state/claude/skills/merged"
  expect "H-16: the sandbox is down and up once" equals "$(grep -c 'ARGS: compose .* \(up\|down\)' "$FAKE_LOG")" "2"
  expect "H-16: the sandbox is up at the end" test -f "$WORK/state/container"
  reset_state
  make_fixture_run
  fake_start_sync "$FIXTURE"
  run_standalone "$WORK/out.h16.nosync" h16-sync-refreshes-and-spares.sh FAKE_NO_SYNC=1
  expect "H-16: a restart where the hook never ran fails" equals "$CHECK_RC" "1"
  expect "H-16: the stale rule is named" has_text "$WORK/out.h16.nosync" "h16-stale.md"
  expect "H-16: the stale GSD version is named" has_text "$WORK/out.h16.nosync" "gsd-core/VERSION"
  reset_state
  make_fixture_run
  fake_start_sync "$FIXTURE"
  run_standalone "$WORK/out.h16.settings" h16-sync-refreshes-and-spares.sh FAKE_GSD_DROPS_SETTINGS=1
  expect "H-16: a sync that drops the user's settings fails" equals "$CHECK_RC" "1"
  expect "H-16: the lost settings key is named" has_text "$WORK/out.h16.settings" "settings.json"
  reset_state
  make_fixture_run
  fake_start_sync "$FIXTURE"
  rm -rf "${FIXTURE:?}/state/claude/skills/gsd-fake-skill"
  run_standalone "$WORK/out.h16.nogsd" h16-sync-refreshes-and-spares.sh
  expect "H-16: a sandbox where GSD never synced fails" equals "$CHECK_RC" "1"
  expect "H-16: the missing GSD is named" has_text "$WORK/out.h16.nogsd" "GSD never synced"
  reset_state
  make_fixture_run
  fake_start_sync "$FIXTURE"
  run_standalone "$WORK/out.h16.gsdgone" h16-sync-refreshes-and-spares.sh FAKE_SYNC_DROPS_GSD_SKILL=1
  expect "H-16: a restart that removes the GSD skill fails" equals "$CHECK_RC" "1"
  expect "H-16: the missing GSD skill file is named" has_text "$WORK/out.h16.gsdgone" "state/claude/skills/gsd-fake-skill/SKILL.md is missing after the restart"
  reset_state
  make_fixture_run
  fake_start_sync "$FIXTURE"
  run_standalone "$WORK/out.h16.clobber" h16-sync-refreshes-and-spares.sh FAKE_SYNC_CLOBBERS=1
  expect "H-16: a restart that deletes user skills fails" equals "$CHECK_RC" "1"
  expect "H-16: the lost user skill is named" has_text "$WORK/out.h16.clobber" "h16-user-skill"
  reset_state
  FIXTURE=""
  run_standalone "$WORK/out.h16.none" h16-sync-refreshes-and-spares.sh
  expect "H-16: no test sandbox fails" equals "$CHECK_RC" "1"
  expect "H-16: no test sandbox says to run run-all.sh first" has_text "$WORK/out.h16.none" "run-all.sh first"
}

# --------------------------------------------------------------------------------
# Main / Entry Point
# --------------------------------------------------------------------------------
require_no_arguments "$@" || exit 2
start_group || exit 1
case_h16_alone
finish_cases
