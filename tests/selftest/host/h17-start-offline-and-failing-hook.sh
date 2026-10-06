#!/usr/bin/env bash
# Self-test of H-17 (tests/host/h17-start-offline-and-failing-hook.sh) against the fake docker: an offline start that syncs and a failing hook that stops pass; an offline start that fails, a hook that does not stop the start and bad hook folders fail.
# - Run by run-all.sh; runs alone too.
# - Makes one work folder under TMPDIR and removes only that folder at exit.
# - Usage, from anywhere: bash tests/selftest/host/h17-start-offline-and-failing-hook.sh   (exit 0 = every case passes)
set -u
. "$(dirname "$0")/lib.sh"

# --------------------------------------------------------------------------------
# Cases of H-17, each run alone against the fake docker
# --------------------------------------------------------------------------------
case_h17_alone() {
  echo "--- H-17 on its own"
  reset_state
  make_fixture_run
  run_standalone "$WORK/out.h17" h17-start-offline-and-failing-hook.sh
  expect "H-17: an offline start that syncs and a failing hook that stops pass" equals "$CHECK_RC" "0"
  expect "H-17: prints PASS: H-17" has_text "$WORK/out.h17" "PASS: H-17"
  expect "H-17: the offline start synced the rules into its own folder"   diff -r -q "$REPO/best-practices/rules" "$FIXTURE/h17/state/claude/rules"
  expect "H-17: the test sandbox state was not touched" test ! -e "$FIXTURE/state/claude"
  sed 's/^.*ARGS: //' "$FAKE_LOG" >"$WORK/args.h17"
  expect "H-17: all four containers run with --rm, no network, no capabilities, no new privileges"   equals "$(grep -c '^run --rm --network none --cap-drop ALL --security-opt no-new-privileges:true ' "$WORK/args.h17")" "4"
  expect "H-17: all four containers mount the run folder as the workspace"   equals "$(grep -F -c "type=bind,source=$FIXTURE/h17,target=/home/sandbox/workspace" "$WORK/args.h17")" "4"
  expect "H-17: two containers mount their own hook folder read-only over the image hooks"   equals "$(grep -F -c ",target=/etc/sbx/start.d,readonly" "$WORK/args.h17")" "2"
  expect "H-17: the hook folders sit under the run folder"   equals "$(grep -F -c "source=$FIXTURE/h17/hooks-" "$WORK/args.h17")" "2"
  expect "H-17: the not-executable hook is a file without the execute bit" test -f "$FIXTURE/h17/hooks-not-executable/10-not-executable"
  expect "H-17: the not-executable hook has no execute bit" test ! -x "$FIXTURE/h17/hooks-not-executable/10-not-executable"
  expect "H-17: the dangling hook is a link" test -L "$FIXTURE/h17/hooks-dangling/10-dangling"
  expect "H-17: the dangling hook link points nowhere" test ! -e "$FIXTURE/h17/hooks-dangling/10-dangling"
  expect "H-17: only the failing container gets a broken config folder"   equals "$(grep -c 'CLAUDE_CONFIG_DIR=/proc/no-such-dir' "$WORK/args.h17")" "1"
  run_standalone "$WORK/out.h17.offline" h17-start-offline-and-failing-hook.sh FAKE_OFFLINE_FAIL=1
  expect "H-17: an offline start that fails fails the check" equals "$CHECK_RC" "1"
  expect "H-17: the offline start is named" has_text "$WORK/out.h17.offline" "offline start"
  run_standalone "$WORK/out.h17.ignored" h17-start-offline-and-failing-hook.sh FAKE_HOOK_IGNORED=1
  expect "H-17: a failing hook that does not stop the start fails the check" equals "$CHECK_RC" "1"
  expect "H-17: the command that ran is reported" has_text "$WORK/out.h17.ignored" "command ran"
  run_standalone "$WORK/out.h17.hookdir" h17-start-offline-and-failing-hook.sh FAKE_HOOK_DIR_IGNORED=1
  expect "H-17: hook folders that do not stop the start fail the check" equals "$CHECK_RC" "1"
  expect "H-17: the not-executable hook is named" has_text "$WORK/out.h17.hookdir" "is not executable"
  expect "H-17: the dangling hook is named" has_text "$WORK/out.h17.hookdir" "is not a regular file"
  reset_state
  FIXTURE=""
  run_standalone "$WORK/out.h17.none" h17-start-offline-and-failing-hook.sh
  expect "H-17: no run folder fails" equals "$CHECK_RC" "1"
  expect "H-17: no run folder says so" has_text "$WORK/out.h17.none" "no run folder"
}

# --------------------------------------------------------------------------------
# Main / Entry Point
# --------------------------------------------------------------------------------
require_no_arguments "$@" || exit 2
start_group || exit 1
case_h17_alone
finish_cases
