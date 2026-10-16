#!/usr/bin/env bash
# ------------------------------------------------------------------------------
# Guard: a few rules the sandbox files must never break
# ------------------------------------------------------------------------------
# Usage, from anywhere: bash tests/guard/run-all.sh (exit 0 = all rules hold)
# What each suite is for and when to add a check: tests/README.md
# ------------------------------------------------------------------------------
set -u
. "$(dirname "$0")/lib.sh"

failCount=0

# ------------------------------------------------------------------------------
# run_groups SUITE_DIR: runs every group program in SUITE_DIR, counts failCount
# ------------------------------------------------------------------------------
# A group that crashes without a FAIL line counts as one failure.
# ------------------------------------------------------------------------------
run_groups() {
  local suiteDir=$1
  local group
  local groupName
  local groupOutput
  local groupStatus
  local groupFailCount

  for group in "$suiteDir"/*.sh; do
    groupName=${group##*/}

    case "$groupName" in
      lib.sh | run-all.sh)
        continue
        ;;
    esac

    groupOutput=$(bash "$group" </dev/null 2>&1)
    groupStatus=$?

    if [ -n "$groupOutput" ]; then
      printf '%s\n' "$groupOutput"
    fi

    groupFailCount=$(printf '%s\n' "$groupOutput" | grep -c '^FAIL:')
    failCount=$((failCount + groupFailCount))

    if [ "$groupStatus" -ne 0 ] && [ "$groupFailCount" -eq 0 ]; then
      echo "FAIL: $groupName stopped with exit status $groupStatus before reporting a rule"
      failCount=$((failCount + 1))
    fi
  done
}

# ------------------------------------------------------------------------------
# print_summary: prints the summary and exits 0 only when every rule held
# ------------------------------------------------------------------------------
print_summary() {
  if [ "$failCount" -eq 0 ]; then
    echo "All rules hold."
    exit 0
  fi

  echo "$failCount rule(s) broken."
  exit 1
}

# ------------------------------------------------------------------------------
# Main / Entry Point
# ------------------------------------------------------------------------------
require_no_arguments "$@" || exit 2
run_groups "$(dirname "$0")"
print_summary
