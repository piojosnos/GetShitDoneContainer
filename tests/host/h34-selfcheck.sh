#!/usr/bin/env bash
# ------------------------------------------------------------------------------
# H-34: sbx-selfcheck passes in a Claude and a Cursor test sandbox
# ------------------------------------------------------------------------------
# Needs: test sandbox running; starts and removes a Cursor test sandbox
# A fresh sandbox correctly fails the git identity and login checks, so this
# plants a git identity and a fake login before each run. The Cursor sandbox
# runs on its own folder with a space in its path and its own registry inside
# the run folder. It is removed before H-34 ends, because H-32 and H-33 compare
# every sbx- container.
# H-34 also plants a root-owned folder in the Claude test sandbox through a
# throwaway root container of the test base image, expects the Mac owner fix in
# the FAIL line, runs that fix and expects the check to pass.
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
# and in claude/selfcheck/claude.py or cursor/selfcheck/cursor.py; an inventory
# test in tests/selftest/selfcheck keeps them equal.
# ------------------------------------------------------------------------------
expectedClaudeCount=53
expectedCursorCount=51

plantedDirName=h34-root-owned
containerStateDir=/home/sandbox/workspace/state
cursorName=hosttest-cursor
cursorContainer=sbx-hosttest-cursor
plantText="h34-$$-$(date +%s)"
rootCaFingerprint=""
cursorAdded=0
selfcheckStatus=0
sbxDir=""
sbxStatus=0

# ------------------------------------------------------------------------------
# read_root_ca_fingerprint: sets rootCaFingerprint from the test root
# ------------------------------------------------------------------------------
read_root_ca_fingerprint() {
  local certFile

  certFile=$(test_root_ca_file)
  rootCaFingerprint=$(cert_fingerprint "$certFile")

  if [ -z "$rootCaFingerprint" ]; then
    add_problem "there is no test root certificate at $certFile; bash tests/host/run-all.sh makes it"
  fi
}

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
# check_selfcheck_output LABEL OUTPUT_FILE EXPECTED_COUNT: count, FAILs, root
# ------------------------------------------------------------------------------
# Always returns 0 and reports only through add_problem. The certificate lines
# match the test root's fingerprint, never a certificate count, since your own
# root may sit next to it. An empty fingerprint skips that part: its problem is
# already recorded.
# ------------------------------------------------------------------------------
check_selfcheck_output() {
  local label=$1
  local outputFile=$2
  local expectedCount=$3
  local lineCount line pendingFail checkName

  lineCount=$(grep -Ec '^(PASS|FAIL): ' "$outputFile" 2>/dev/null)
  lineCount=${lineCount:-0}

  if [ "$lineCount" -ne "$expectedCount" ]; then
    add_problem "$label: sbx-selfcheck printed $lineCount check lines, expected $expectedCount; first lines: $(first_lines "$(cat "$outputFile" 2>/dev/null)"); checks are declared in the CHECK_LIST of each file in base/selfcheck/checks/ and in claude/selfcheck/claude.py or cursor/selfcheck/cursor.py, and the count is in tests/host/h34-selfcheck.sh"
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

  if [ -z "$rootCaFingerprint" ]; then
    return 0
  fi

  for checkName in extra-ca-system-bundle extra-ca-java-cacerts; do
    if ! grep -F -- "PASS: $checkName: " "$outputFile" 2>/dev/null | grep -qF -- "$rootCaFingerprint"; then
      add_problem "$label: no PASS line of $checkName names the test root certificate $rootCaFingerprint"
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
  report_selfcheck_summary "Claude test sandbox" "$outputFile"
}

# ------------------------------------------------------------------------------
# root_run LOG_NAME ENTRYPOINT ARG...: runs one throwaway root container
# ------------------------------------------------------------------------------
# The container is the test base image with the test sandbox's mount, so it
# reaches only the run folder. Output goes to $RUN/logs/h34-LOG_NAME.log. Returns
# the docker exit status.
# ------------------------------------------------------------------------------
root_run() {
  local logName=$1
  local entrypoint=$2

  shift 2
  run_timeout 120 docker run --rm --network none -u root --entrypoint "$entrypoint" \
    --volumes-from "$CONTAINER" "$BASE_IMAGE" "$@" >"$RUN/logs/h34-$logName.log" 2>&1 </dev/null
}

# ------------------------------------------------------------------------------
# check_owner_fix_line OUTPUT_FILE: the FAIL names the folder and gives the fix
# ------------------------------------------------------------------------------
# Only greps fixed fragments out of the output. The tag in the image name is not
# asserted, because host checks never spell out the tag your sandboxes run.
# ------------------------------------------------------------------------------
check_owner_fix_line() {
  local outputFile=$1
  local failLine fixLine shownFixLine
  local fixStart="on the Mac run: docker run --rm --network none -u root --entrypoint chown --volumes-from $CONTAINER sbx-base:"
  local fixEnd=" -R 1000:1000 $containerStateDir"

  failLine=$(grep '^FAIL: no-root-owned-state: ' "$outputFile" 2>/dev/null | head -n 1)
  fixLine=$(grep -A 1 '^FAIL: no-root-owned-state: ' "$outputFile" 2>/dev/null | sed -n 2p)
  shownFixLine=$(printf '%s\n' "$fixLine" | sed 's/^ *//')

  if [ -z "$failLine" ]; then
    add_problem "owner fix, before: no FAIL line of no-root-owned-state for the planted folder $plantedDirName; output: $outputFile"
  elif [[ "$failLine" != *"$plantedDirName"* ]]; then
    add_problem "owner fix, before: the FAIL line does not name $plantedDirName: $failLine; output: $outputFile"
  fi

  if [[ "$fixLine" != *"$fixStart"* || "$fixLine" != *"$fixEnd"* ]]; then
    add_problem "owner fix, before: the line under the no-root-owned-state FAIL does not hold the Mac owner fix for $containerStateDir: $fixLine; output: $outputFile"
  fi

  info "H-34 owner fix line: $shownFixLine"
}

# ------------------------------------------------------------------------------
# check_owner_fix: the doctor round trip in the Claude test sandbox
# ------------------------------------------------------------------------------
# Plants a root-owned mode 700 folder in state/, expects the FAIL with the Mac
# fix, runs H-34's own copy of that fix with the test base image and expects the
# check to pass. Never runs text taken from the output. A failed plant has
# recorded its problem, so nothing more runs.
# ------------------------------------------------------------------------------
check_owner_fix() {
  local beforeFile=$RUN/logs/h34-owner-fix-before.out
  local afterFile=$RUN/logs/h34-owner-fix-after.out

  if ! root_run plant mkdir -m 700 "$containerStateDir/$plantedDirName"; then
    add_problem "could not plant the root-owned folder $plantedDirName in the Claude test sandbox; log: $RUN/logs/h34-plant.log"

    return 0
  fi

  run_selfcheck "$CONTAINER" "$beforeFile"

  if [ "$selfcheckStatus" -ne 1 ]; then
    add_problem "owner fix, before: sbx-selfcheck exited $selfcheckStatus, expected 1 for the planted root-owned folder; output: $beforeFile"
  fi

  check_owner_fix_line "$beforeFile"
  report_selfcheck_summary "owner fix, before" "$beforeFile"

  if ! root_run chown chown -R 1000:1000 "$containerStateDir"; then
    add_problem "owner fix: the chown of $containerStateDir as root failed; log: $RUN/logs/h34-chown.log"
  fi

  run_selfcheck "$CONTAINER" "$afterFile"
  check_selfcheck_status "owner fix, after" "$afterFile"

  if grep -q '^FAIL: no-root-owned-state: ' "$afterFile" 2>/dev/null; then
    add_problem "owner fix, after: no-root-owned-state still fails after the owner fix; output: $afterFile"
  fi

  report_selfcheck_summary "owner fix, after" "$afterFile"
}

# ------------------------------------------------------------------------------
# remove_planted_folder: removes the planted folder and confirms it is gone
# ------------------------------------------------------------------------------
# Runs whatever happened before, so the later checks never find a root-owned
# folder in the run folder's state.
# ------------------------------------------------------------------------------
remove_planted_folder() {
  root_run cleanup rm -rf "$containerStateDir/$plantedDirName"

  if [ -e "$RUN/state/$plantedDirName" ]; then
    add_problem "the planted folder $RUN/state/$plantedDirName is still there; remove it by hand with: rm -rf \"$RUN/state/$plantedDirName\"; log: $RUN/logs/h34-cleanup.log"
  fi

  return 0
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
read_root_ca_fingerprint
check_claude_sandbox
check_owner_fix
remove_planted_folder
check_cursor_sandbox
remove_cursor_sandbox
report_check H-34 "sbx-selfcheck failed, printed the wrong number of checks, the Cursor test sandbox did not start or go away, or the owner fix round trip failed" \
  "sbx-selfcheck printed $expectedClaudeCount PASS lines in the Claude test sandbox and $expectedCursorCount in a Cursor test sandbox, found the test root certificate in the system bundle and Java cacerts in both, failed no-root-owned-state on a planted root-owned folder with the Mac owner fix and passed after running it, and the Cursor test sandbox is gone"
