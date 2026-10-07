#!/usr/bin/env bash
# Self-test of the Coexistence check (tests/host/coexistence.sh) against the fake docker: equal snapshots and clean old folders pass; a changed snapshot or a change under ClaudeCode/ fails; no baseline passes on git alone.
# - Run by run-all.sh; runs alone too.
# - Makes one work folder under TMPDIR and removes only that folder at exit.
# - Copies tests/host/*.sh into a scratch repo under the work folder, so tests/host/ stays exactly two levels deep.
# - Usage, from anywhere: bash tests/selftest/host/coexistence.sh   (exit 0 = every case passes)
set -u
. "$(dirname "$0")/lib.sh"

# --------------------------------------------------------------------------------
# Cases of Coexistence, each run alone against the fake docker
# --------------------------------------------------------------------------------
case_coexistence_alone() {
  echo "--- Coexistence on its own"
  reset_state
  make_fixture_run
  printf 'deadbeef0001 cc_oldbox running\n' >"$FIXTURE/logs/old-containers.before"
  run_standalone "$WORK/out.co" coexistence.sh
  expect "Coexistence: equal snapshots and clean old folders pass" equals "$CHECK_RC" "0"
  expect "Coexistence: prints PASS: Coexistence" has_text "$WORK/out.co" "PASS: Coexistence"
  run_standalone "$WORK/out.co.changed" coexistence.sh FAKE_PS="deadbeef0001 cc_oldbox exited"
  expect "Coexistence: a changed snapshot fails" equals "$CHECK_RC" "1"
  expect "Coexistence: a changed snapshot shows the before side" has_text "$WORK/out.co.changed" "cc_oldbox running"
  expect "Coexistence: a changed snapshot shows the after side" has_text "$WORK/out.co.changed" "cc_oldbox exited"
  expect "Coexistence: a changed snapshot says to re-run" has_text "$WORK/out.co.changed" "re-run"
  expect "Coexistence: the baseline is left as it was" \
    equals "$(cat "$FIXTURE/logs/old-containers.before")" "deadbeef0001 cc_oldbox running"
  reset_state
  FIXTURE=""
  run_standalone "$WORK/out.co.nobase" coexistence.sh
  expect "Coexistence: no baseline passes on git alone" equals "$CHECK_RC" "0"
  expect "Coexistence: no baseline says so" has_text "$WORK/out.co.nobase" "git only; no baseline"
  mkdir -p "$WORK/scratchrepo/tests/host" "$WORK/scratchrepo/ClaudeCode"
  cp tests/host/*.sh "$WORK/scratchrepo/tests/host/"
  git -C "$WORK/scratchrepo" init -q
  : >"$WORK/scratchrepo/ClaudeCode/stray.txt"
  CHECK_RC=0
  env SBXTEST_DIR="" bash "$WORK/scratchrepo/tests/host/coexistence.sh" >"$WORK/out.co.git" 2>&1 </dev/null || CHECK_RC=$?
  expect "Coexistence: a change under ClaudeCode/ fails" equals "$CHECK_RC" "1"
  expect "Coexistence: the changed path is shown" has_text "$WORK/out.co.git" "stray.txt"
}

# --------------------------------------------------------------------------------
# failed_with STATUS FILE TEXT: true if STATUS is 1 and FILE contains TEXT.
# --------------------------------------------------------------------------------
failed_with() {
  [ "$1" = 1 ] && has_text "$2" "$3"
}

# --------------------------------------------------------------------------------
# scratch_git REPO ARG...: runs git in REPO with the user's own git configuration switched off.
# --------------------------------------------------------------------------------
scratch_git() {
  local repoPath=$1

  shift
  env GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_NOSYSTEM=1 git -C "$repoPath" -c user.name=Scratch -c user.email=scratch@example.invalid "$@"
}

# --------------------------------------------------------------------------------
# make_scratch_repo NAME: makes WORK/NAME with a copy of tests/host/*.sh and one committed file in each old folder.
# --------------------------------------------------------------------------------
make_scratch_repo() {
  local repoPath=$WORK/$1

  mkdir -p "$repoPath/tests/host" "$repoPath/ClaudeCode" "$repoPath/OpenCode"
  cp tests/host/*.sh "$repoPath/tests/host/"
  : >"$repoPath/ClaudeCode/keep.txt"
  : >"$repoPath/OpenCode/keep.txt"
  scratch_git "$repoPath" init -q
  scratch_git "$repoPath" add ClaudeCode OpenCode
  scratch_git "$repoPath" commit -q -m scratch
}

# --------------------------------------------------------------------------------
# run_scratch_check OUTFILE NAME [VAR=VALUE...]: runs coexistence.sh from WORK/NAME with SBXTEST_DIR at FIXTURE (when set); sets CHECK_RC.
# --------------------------------------------------------------------------------
run_scratch_check() {
  local outFile=$1
  local repoName=$2

  shift 2
  CHECK_RC=0
  env SBX_NAME=demo SBX_DIR=/elsewhere COMPOSE_PROJECT_NAME=evil SBXTEST_DIR="${FIXTURE:-}" \
    GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_NOSYSTEM=1 "$@" \
    bash "$WORK/$repoName/tests/host/coexistence.sh" >"$outFile" 2>&1 </dev/null || CHECK_RC=$?
}

# --------------------------------------------------------------------------------
# Cases of Coexistence against the baselines of the start of the run
# --------------------------------------------------------------------------------
case_coexistence_baselines() {
  echo "--- Coexistence against the start of the run"
  reset_state
  make_scratch_repo oldrepo
  : >"$WORK/oldrepo/ClaudeCode/stray.txt"
  make_fixture_run
  printf 'deadbeef0001 cc_oldbox running\n' >"$FIXTURE/logs/old-containers.before"
  ( . "$WORK/oldrepo/tests/host/lib.sh"; host_init; snapshot_old_folders ) >"$FIXTURE/logs/old-folders.before" 2>/dev/null
  run_scratch_check "$WORK/out.co.dirty" oldrepo
  expect "Coexistence: a dirty old folder that did not change passes" equals "$CHECK_RC" "0"
  expect "Coexistence: both snapshots are compared" has_text "$WORK/out.co.dirty" "container and folder snapshots"
  : >"$WORK/oldrepo/ClaudeCode/new.txt"
  run_scratch_check "$WORK/out.co.newfile" oldrepo
  expect "Coexistence: a change to the old folders during the run fails" equals "$CHECK_RC" "1"
  expect "Coexistence: the new file is named" has_text "$WORK/out.co.newfile" "new.txt"

  reset_state
  make_fixture_run
  : >"$FIXTURE/logs/old-containers.before"
  run_standalone "$WORK/out.co.psfail" coexistence.sh FAKE_PS_FAIL=1
  expect "Coexistence: a failed docker ps is reported, not compared" failed_with "$CHECK_RC" "$WORK/out.co.psfail" "docker ps failed"

  reset_state
  FIXTURE=""
  mkdir -p "$WORK/nogit/tests/host"
  cp tests/host/*.sh "$WORK/nogit/tests/host/"
  run_scratch_check "$WORK/out.co.nogit" nogit GIT_CEILING_DIRECTORIES="$WORK"
  expect "Coexistence: a git error is reported as an error, not as changes" failed_with "$CHECK_RC" "$WORK/out.co.nogit" "git could not read"
  expect "Coexistence: a git error is not called a change" lacks_text "$WORK/out.co.nogit" "git status shows changes"
}

# --------------------------------------------------------------------------------
# Main / Entry Point
# --------------------------------------------------------------------------------
require_no_arguments "$@" || exit 2
start_group || exit 1
case_coexistence_alone
case_coexistence_baselines
finish_cases
