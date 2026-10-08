#!/usr/bin/env bash
# Self-test of H-08 (tests/host/h08-history-survives-recreate.sh) against the fake docker: a history that is never written or is lost on recreate fails.
# - Run by run-all.sh; runs alone too.
# - Makes one work folder under TMPDIR and removes only that folder at exit.
# - Usage, from anywhere: bash tests/selftest/host/h08-history-survives-recreate.sh   (exit 0 = every case passes)
set -u
. "$(dirname "$0")/lib.sh"

# --------------------------------------------------------------------------------
# run_h08_in_session OUTFILE [VAR=VALUE...]: runs H-08 alone in a session of its own, with the decoys exported and SBXTEST_DIR at FIXTURE; sets CHECK_RC and H08_SID.
# --------------------------------------------------------------------------------
# The session id is written before the check starts, so a case can look for processes the check left behind.
run_h08_in_session() {
  local outFile=$1

  shift
  CHECK_RC=0
  env SBX_NAME=demo SBX_DIR=/elsewhere COMPOSE_PROJECT_NAME=evil SBXTEST_DIR="${FIXTURE:-}" "$@" \
    setsid -w bash -c 'ps -o sid= -p $$ | tr -d " " >"$1"; exec bash tests/host/h08-history-survives-recreate.sh' \
    sh "$WORK/h08.sid" >"$outFile" 2>&1 </dev/null || CHECK_RC=$?
  H08_SID=$(cat "$WORK/h08.sid")
}

# --------------------------------------------------------------------------------
# session_is_empty SID: true when no process of session SID is alive after at most 2 s; else lists the leftovers on stderr.
# --------------------------------------------------------------------------------
session_is_empty() {
  local i leftover

  case "$1" in
    '' | *[!0-9]*) return 1 ;;
  esac

  for i in $(seq 1 20); do
    leftover=$(pgrep -s "$1")

    if [ -z "$leftover" ]; then
      return 0
    fi
    sleep 0.1
  done

  echo "leftover processes of session $1:" >&2
  ps -o pid,args -p "$(printf '%s' "$leftover" | tr '\n' ',')" >&2

  return 1
}

# --------------------------------------------------------------------------------
# Cases of H-08, each run alone against the fake docker
# --------------------------------------------------------------------------------
case_h08_alone() {
  echo "--- H-08 on its own"
  reset_state
  make_fixture_run
  run_h08_in_session "$WORK/out.h08"
  expect "H-08: a marker written while a shell is open survives the recreate" equals "$CHECK_RC" "0"
  expect "H-08: prints PASS: H-08" has_text "$WORK/out.h08" "PASS: H-08"
  expect "H-08: the history file is in the run folder" has_text "$FIXTURE/state/shell/bash_history" "echo marker-"
  expect "H-08: the sandbox is down and up once" equals "$(grep -c 'ARGS: compose .* \(up\|down\)' "$FAKE_LOG")" "2"
  expect "H-08: a passing run leaves nothing running" session_is_empty "$H08_SID"
  reset_state
  make_fixture_run
  run_h08_in_session "$WORK/out.h08.nohist" FAKE_NO_HISTORY=1
  expect "H-08: a marker that never reaches the history file fails" equals "$CHECK_RC" "1"
  expect "H-08: the failing half is the first one" has_text "$WORK/out.h08.nohist" "before the recreate"
  expect "H-08: a run that fails before the recreate leaves nothing running" session_is_empty "$H08_SID"
  reset_state
  make_fixture_run
  run_h08_in_session "$WORK/out.h08.lost" FAKE_DOWN_LOSES_HISTORY=1
  expect "H-08: history lost by the recreate fails" equals "$CHECK_RC" "1"
  expect "H-08: the failing half is the second one" has_text "$WORK/out.h08.lost" "after the recreate"
  expect "H-08: a run that fails after the recreate leaves nothing running" session_is_empty "$H08_SID"
}

# --------------------------------------------------------------------------------
# Main / Entry Point
# --------------------------------------------------------------------------------
require_no_arguments "$@" || exit 2
start_group || exit 1
case_h08_alone
finish_cases
