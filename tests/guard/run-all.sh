#!/usr/bin/env bash
# Guard: a few rules the sandbox files must never break.
# - Reads the files only. Builds nothing, runs nothing; no Docker needed.
# - Each rule is one function in a group file next to this runner. Its comment says what it protects.
# - These are mistakes a manual test would not notice, because the sandbox still works.
# - Real behavior is tested on the Mac: tests/host/run-all.sh and tests/host-checklist.md.
# - Usage, from anywhere: bash tests/guard/run-all.sh   (exit 0 = all rules hold)
# - Runs only when started by hand: you, or an agent's verify step. No hook, no CI.
set -u
. "$(dirname "$0")/lib.sh"

# --------------------------------------------------------------------------------
# Group programs, in run order
# --------------------------------------------------------------------------------
groupList="supply-chain.sh start.sh isolation.sh host-tests.sh suites.sh planning-ids.sh docs.sh bundle-content.sh bundle-wiring.sh"
failCount=0

# --------------------------------------------------------------------------------
# run_groups SUITE_DIR GROUP...: runs each group program, prints its output and adds its FAIL lines to failCount.
# --------------------------------------------------------------------------------
# A group that stops with a non-zero status and no FAIL line counts as one failure, so a crash is never silent.
run_groups() {
  local suiteDir=$1
  local group
  local groupOutput
  local groupStatus
  local groupFailCount

  shift

  for group in "$@"; do
    groupOutput=$(bash "$suiteDir/$group" </dev/null 2>&1)
    groupStatus=$?

    if [ -n "$groupOutput" ]; then
      printf '%s\n' "$groupOutput"
    fi

    groupFailCount=$(printf '%s\n' "$groupOutput" | grep -c '^FAIL:')
    failCount=$((failCount + groupFailCount))

    if [ "$groupStatus" -ne 0 ] && [ "$groupFailCount" -eq 0 ]; then
      echo "FAIL: $group stopped with exit status $groupStatus before reporting a rule"
      failCount=$((failCount + 1))
    fi
  done
}

# --------------------------------------------------------------------------------
# print_summary: prints the summary and exits 0 only when every rule held.
# --------------------------------------------------------------------------------
print_summary() {
  if [ "$failCount" -eq 0 ]; then
    echo "All rules hold."
    exit 0
  fi

  echo "$failCount rule(s) broken."
  exit 1
}

# --------------------------------------------------------------------------------
# Main / Entry Point
# --------------------------------------------------------------------------------
require_no_arguments "$@" || exit 2
run_groups "$(dirname "$0")" $groupList
print_summary
