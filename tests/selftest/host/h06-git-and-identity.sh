#!/usr/bin/env bash
# Self-test of H-06 (tests/host/h06-git-and-identity.sh) against the fake docker: a clean git setup passes with the host git config untouched; a dubious ownership message, a missing identity file and a safe.directory value that is not * fail.
# - Run by run-all.sh; runs alone too.
# - Makes one work folder under TMPDIR and removes only that folder at exit.
# - Usage, from anywhere: bash tests/selftest/host/h06-git-and-identity.sh   (exit 0 = every case passes)
set -u
. "$(dirname "$0")/lib.sh"

# --------------------------------------------------------------------------------
# Cases of H-06, each run alone against the fake docker
# --------------------------------------------------------------------------------
case_h06_alone() {
  echo "--- H-06 on its own"
  reset_state
  make_fixture_run
  mkdir -p "$WORK/fakehome/tpl"
  printf 'template marker\n' >"$WORK/fakehome/tpl/MARK"
  printf '[init]\n\ttemplateDir = %s\n[user]\n\tname = Real Person\n' "$WORK/fakehome/tpl" >"$WORK/fakehome/.gitconfig"
  cp "$WORK/fakehome/.gitconfig" "$WORK/gitconfig.before"
  run_standalone "$WORK/out.h06" h06-git-and-identity.sh HOME="$WORK/fakehome"
  expect "H-06: no dubious ownership, safe.directory * and the identity file pass" equals "$CHECK_RC" "0"
  expect "H-06: prints PASS: H-06" has_text "$WORK/out.h06" "PASS: H-06"
  expect "H-06: the host-side git init made a repository" test -d "$FIXTURE/hosttest/.git"
  expect "H-06: the run's identity is in the identity file" has_match "$FIXTURE/state/git/config" 'name = hosttest-[0-9]+-[0-9]+$'
  expect "H-06: the host git config is not read (its template folder was not used)" test ! -e "$FIXTURE/hosttest/.git/MARK"
  expect "H-06: the host git config file is untouched" cmp -s "$WORK/fakehome/.gitconfig" "$WORK/gitconfig.before"
  reset_state
  make_fixture_run
  run_standalone "$WORK/out.h06.dubious" h06-git-and-identity.sh FAKE_GIT_DUBIOUS=1
  expect "H-06: a dubious ownership message fails" equals "$CHECK_RC" "1"
  expect "H-06: the dubious ownership message is shown" has_text "$WORK/out.h06.dubious" "dubious ownership"
  reset_state
  make_fixture_run
  run_standalone "$WORK/out.h06.nowrite" h06-git-and-identity.sh FAKE_NO_GIT_WRITE=1
  expect "H-06: a missing identity file fails" equals "$CHECK_RC" "1"
  expect "H-06: the missing identity file is named" has_text "$WORK/out.h06.nowrite" "state/git/config"
  reset_state
  make_fixture_run
  mkdir -p "$FIXTURE/state/git"
  printf '[user]\n\tname = T\n' >"$FIXTURE/state/git/config"
  run_standalone "$WORK/out.h06.stale" h06-git-and-identity.sh FAKE_NO_GIT_WRITE=1
  expect "H-06: an identity left by an earlier run does not pass" equals "$CHECK_RC" "1"
  run_standalone "$WORK/out.h06.safe" h06-git-and-identity.sh FAKE_SAFE_DIR=/home/sandbox/workspace
  expect "H-06: a safe.directory value that is not * fails" equals "$CHECK_RC" "1"
}

# --------------------------------------------------------------------------------
# Main / Entry Point
# --------------------------------------------------------------------------------
require_no_arguments "$@" || exit 2
start_group || exit 1
case_h06_alone
finish_cases
