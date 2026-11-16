#!/usr/bin/env bash
# ------------------------------------------------------------------------------
# H-34: sbx-selfcheck passes in a Claude and a Cursor test sandbox
# ------------------------------------------------------------------------------
# Needs: test sandbox running; starts and removes a Cursor test sandbox
# A fresh sandbox correctly fails the git identity and login checks, so this
# plants a git identity and a fake login before each run. The Cursor sandbox
# runs on its own folder with a space in its path and its own registry inside
# the run folder. It is removed before H-34 ends, because H-32 and H-33 compare
# every sbx- container. The test images are always built with a root certificate,
# so no certificate check may print that none was requested; that would mean the
# build lost the certificate and its fingerprint together.
# ------------------------------------------------------------------------------
set -u
. "$(dirname "$0")/lib.sh"
host_init
. "$(dirname "$0")/lib-sbx.sh"
. "$(dirname "$0")/lib-bundle.sh"

# ------------------------------------------------------------------------------
# Expected check counts: the shared checks plus the agent's own
# ------------------------------------------------------------------------------
# Count the check entries in the CHECK_LIST of each file in base/selfcheck/checks/
# and in claude/selfcheck/ or cursor/selfcheck/; an inventory test in
# tests/selftest/selfcheck keeps them equal.
# ------------------------------------------------------------------------------
expectedClaudeCount=53
expectedCursorCount=51

cursorName=hosttest-cursor
cursorContainer=sbx-hosttest-cursor
plantText="h34-$$-$(date +%s)"
cursorAdded=0
selfcheckStatus=0
sbxDir=""
sbxStatus=0

# ------------------------------------------------------------------------------
# plant_identity CONTAINER: sets a git identity that holds only the run text
# ------------------------------------------------------------------------------
plant_identity() {
  if ! docker exec "$1" git config --global user.name "$plantText" </dev/null; then
    add_problem "could not set git user.name in $1"
  fi

  if ! docker exec "$1" git config --global user.email "$plantText@example.invalid" </dev/null; then
    add_problem "could not set git user.email in $1"
  fi
}

# ------------------------------------------------------------------------------
# plant_fake_login FILE: writes a fake login file that holds only the run text
# ------------------------------------------------------------------------------
plant_fake_login() {
  if ! mkdir -p "$(dirname "$1")"; then
    add_problem "could not make the folder of the fake login file $1"
  fi

  if ! printf '{"fake":"%s"}\n' "$plantText" >"$1"; then
    add_problem "could not write the fake login file $1"
  fi
}

# ------------------------------------------------------------------------------
# run_selfcheck CONTAINER OUTPUT_FILE: runs sbx-selfcheck, sets selfcheckStatus
# ------------------------------------------------------------------------------
run_selfcheck() {
  run_timeout 120 docker exec "$1" sbx-selfcheck >"$2" 2>&1 </dev/null
  selfcheckStatus=$?
}

# ------------------------------------------------------------------------------
# check_selfcheck_status LABEL OUTPUT_FILE: the exit status matches the lines
# ------------------------------------------------------------------------------
# Above 1 is a crash, a failed docker exec, or a stop by run_timeout (143, 137).
# Exit 1 needs a FAIL line; exit 0 needs none.
# ------------------------------------------------------------------------------
check_selfcheck_status() {
  local label=$1
  local outputFile=$2
  local hasFailLine=0

  if grep -q '^FAIL: ' "$outputFile" 2>/dev/null; then
    hasFailLine=1
  fi

  if [ "$selfcheckStatus" -gt 1 ]; then
    add_problem "$label: sbx-selfcheck exited $selfcheckStatus (a crash, a failed docker exec or a timeout); output: $outputFile"
  elif [ "$selfcheckStatus" -eq 1 ] && [ "$hasFailLine" -eq 0 ]; then
    add_problem "$label: sbx-selfcheck exited 1 but printed no FAIL line; output: $outputFile"
  elif [ "$selfcheckStatus" -eq 0 ] && [ "$hasFailLine" -eq 1 ]; then
    add_problem "$label: sbx-selfcheck exited 0 but printed a FAIL line; output: $outputFile"
  fi
}

# ------------------------------------------------------------------------------
# check_selfcheck_output LABEL OUTPUT_FILE EXPECTED_COUNT: count and FAIL lines
# ------------------------------------------------------------------------------
# Always returns 0 and reports only through add_problem. The certificate checks
# compare the fingerprints the image recorded, so a FAIL line covers them.
# ------------------------------------------------------------------------------
check_selfcheck_output() {
  local label=$1
  local outputFile=$2
  local expectedCount=$3
  local lineCount line pendingFail

  lineCount=$(grep -Ec '^(PASS|FAIL): ' "$outputFile" 2>/dev/null)
  lineCount=${lineCount:-0}

  if [ "$lineCount" -ne "$expectedCount" ]; then
    add_problem "$label: sbx-selfcheck printed $lineCount check lines, expected $expectedCount; first lines: $(first_lines "$(cat "$outputFile" 2>/dev/null)"); checks are declared in the CHECK_LIST of each file in base/selfcheck/checks/ and in claude/selfcheck/ or cursor/selfcheck/, and the count is in tests/host/h34-selfcheck.sh"
  fi

  pendingFail=""

  while IFS= read -r line || [ -n "$line" ]; do
    if [ -n "$pendingFail" ]; then
      if [[ "$line" == "      fix: "* ]]; then
        pendingFail="$pendingFail"$'\n'"$line"
        line=""
      fi

      add_problem "$pendingFail"
      pendingFail=""
    fi

    if [[ "$line" == "FAIL: "* ]]; then
      pendingFail="$label: $line"
    fi
  done <"$outputFile"

  if [ -n "$pendingFail" ]; then
    add_problem "$pendingFail"
  fi

  return 0
}

# ------------------------------------------------------------------------------
# check_certificate_requested LABEL OUTPUT_FILE: no certificate check says none was requested
# ------------------------------------------------------------------------------
# Always returns 0 and reports only through add_problem. A FAIL line is already
# reported by check_selfcheck_output.
# ------------------------------------------------------------------------------
check_certificate_requested() {
  local label=$1
  local outputFile=$2
  local checkName

  for checkName in extra-ca-system-bundle extra-ca-java-cacerts; do
    if grep -Fq "PASS: $checkName: no extra root certificate requested" "$outputFile" 2>/dev/null; then
      add_problem "$label: $checkName says no extra root certificate was requested, but the test image is built with one; the build lost the certificate and its fingerprint; output: $outputFile"
    fi
  done

  return 0
}

# ------------------------------------------------------------------------------
# report_selfcheck_summary LABEL OUTPUT_FILE: prints the summary line as INFO
# ------------------------------------------------------------------------------
report_selfcheck_summary() {
  info "H-34 $1: $(tail -n 1 "$2" 2>/dev/null)"
}

# ------------------------------------------------------------------------------
# check_claude_sandbox: runs sbx-selfcheck in the Claude test sandbox
# ------------------------------------------------------------------------------
check_claude_sandbox() {
  local outputFile=$RUN/logs/h34-claude.out

  plant_identity "$CONTAINER"
  plant_fake_login "$RUN/state/claude/.credentials.json"
  run_selfcheck "$CONTAINER" "$outputFile"
  check_selfcheck_status "Claude test sandbox" "$outputFile"
  check_selfcheck_output "Claude test sandbox" "$outputFile" "$expectedClaudeCount"
  check_certificate_requested "Claude test sandbox" "$outputFile"
  report_selfcheck_summary "Claude test sandbox" "$outputFile"
}

# ------------------------------------------------------------------------------
# start_cursor_sandbox: registers, clones the bundle for and starts the sandbox
# ------------------------------------------------------------------------------
# The clone must exist before the start, so the start links its skills.
# ------------------------------------------------------------------------------
start_cursor_sandbox() {
  run_sbx h34-add sbx-add "$cursorName" "$sbxDir" cursor

  if [ "$sbxStatus" -ne 0 ]; then
    add_problem "sbx-add of the Cursor test sandbox exited $sbxStatus; log: $RUN/logs/h34-add.err"

    return 1
  fi

  cursorAdded=1

  if ! make_bundle_clone "$RUN/bundle-origin.git" "$sbxDir/best-practices" >"$RUN/logs/h34-clone.log" 2>&1; then
    add_problem "could not clone the fixture bundle for the Cursor test sandbox; log: $RUN/logs/h34-clone.log"

    return 1
  fi

  run_sbx h34-start sbx-start "$cursorName"

  if [ "$sbxStatus" -ne 0 ]; then
    add_problem "sbx-start of the Cursor test sandbox exited $sbxStatus; log: $RUN/logs/h34-start.err"

    return 1
  fi

  return 0
}

# ------------------------------------------------------------------------------
# check_cursor_sandbox: runs sbx-selfcheck in the Cursor test sandbox
# ------------------------------------------------------------------------------
# A failed start has already recorded its problem, so nothing more runs.
# ------------------------------------------------------------------------------
check_cursor_sandbox() {
  local outputFile=$RUN/logs/h34-cursor.out

  if ! start_cursor_sandbox; then
    return 0
  fi

  plant_identity "$cursorContainer"
  plant_fake_login "$sbxDir/state/cursor/auth.json"
  run_selfcheck "$cursorContainer" "$outputFile"
  check_selfcheck_status "Cursor test sandbox" "$outputFile"
  check_selfcheck_output "Cursor test sandbox" "$outputFile" "$expectedCursorCount"
  check_certificate_requested "Cursor test sandbox" "$outputFile"
  report_selfcheck_summary "Cursor test sandbox" "$outputFile"
}

# ------------------------------------------------------------------------------
# remove_cursor_sandbox: removes the Cursor test sandbox and confirms it is gone
# ------------------------------------------------------------------------------
# Runs whatever happened before, so the chain checks and the next run never see
# a second sandbox.
# ------------------------------------------------------------------------------
remove_cursor_sandbox() {
  if [ "$cursorAdded" -ne 1 ]; then
    return 0
  fi

  run_sbx h34-rm sbx-rm "$cursorName" --yes

  if [ "$sbxStatus" -ne 0 ]; then
    add_problem "sbx-rm of the Cursor test sandbox exited $sbxStatus; log: $RUN/logs/h34-rm.err"
  fi

  if docker container inspect "$cursorContainer" >/dev/null 2>&1 </dev/null; then
    add_problem "the container $cursorContainer is still there; remove it by hand with: docker rm -f $cursorContainer"
  fi

  return 0
}

# ------------------------------------------------------------------------------
# Main / Entry Point
# ------------------------------------------------------------------------------
require_no_arguments "$@" || exit 2
require_test_sandbox H-34 || exit 1
sbx_test_setup H-34 h34 || exit 1
check_claude_sandbox
check_cursor_sandbox
remove_cursor_sandbox
report_check H-34 "sbx-selfcheck failed, printed the wrong number of checks, or the Cursor test sandbox did not start or go away" \
  "sbx-selfcheck printed $expectedClaudeCount PASS lines in the Claude test sandbox and $expectedCursorCount in a Cursor test sandbox, and the Cursor test sandbox is gone"
