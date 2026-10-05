#!/usr/bin/env bash
# Reporting for the host tests: PASS, FAIL and INFO lines, and how a check collects and reports its result.
# - Loaded by lib.sh; never run directly. Defines functions and one list only.
# - A check calls add_problem for each failed assertion and ends with report_check.
# - stop_check ends a check early with FAIL when the rest would mean nothing; pass_check ends it early with PASS.
# - report_result is for a helper that prints several result lines.
# - Host side code is stock bash 3.2 with BSD tools (macOS).

# --------------------------------------------------------------------------------
# Prints one PASS, FAIL or INFO line
# --------------------------------------------------------------------------------

# pass ID TEXT: prints one PASS line.
pass() {
  printf 'PASS: %s %s\n' "$1" "$2"
}

# fail ID TEXT [DETAIL...]: prints one FAIL line, then each detail indented.
fail() {
  local checkId=$1
  local text=$2

  printf 'FAIL: %s %s\n' "$checkId" "$text"
  shift 2
  while [ "$#" -gt 0 ]; do
    printf '      %s\n' "$1"
    shift
  done
}

# info TEXT: prints one INFO line.
info() {
  printf 'INFO: %s\n' "$1"
}

# --------------------------------------------------------------------------------
# Collects a check's problems, then reports its result
# --------------------------------------------------------------------------------

# Every message add_problem collected so far, in the order it was added.
problemList=()

# add_problem MESSAGE: keeps MESSAGE for report_check to print as a FAIL detail.
add_problem() {
  problemList+=("$1")
}

# report_result ID FAIL_SUMMARY PASS_TEXT: FAIL with every problem collected (list emptied, returns 1); else PASS (returns 0).
# The count is tested first: bash 3.2 with set -u treats an empty array as unbound.
report_result() {
  local checkId=$1
  local failSummary=$2
  local passText=$3

  if [ "${#problemList[@]}" -gt 0 ]; then
    fail "$checkId" "$failSummary" "${problemList[@]}"
    problemList=()

    return 1
  fi

  pass "$checkId" "$passText"

  return 0
}

# report_check ID FAIL_SUMMARY PASS_TEXT: report_result, then exit 1 on FAIL or 0 on PASS.
report_check() {
  if report_result "$@"; then
    exit 0
  fi

  exit 1
}

# stop_check ID SUMMARY [DETAIL...]: prints one FAIL line with its details and exits 1.
stop_check() {
  fail "$@"
  exit 1
}

# pass_check ID TEXT: prints one PASS line and exits 0.
pass_check() {
  pass "$1" "$2"
  exit 0
}

# --------------------------------------------------------------------------------
# Shortens command output for a FAIL detail
# --------------------------------------------------------------------------------

# first_lines TEXT [COUNT]: the first COUNT lines of TEXT (default 3) on one line, each followed by a space.
first_lines() {
  local lineCount=${2:-3}

  printf '%s\n' "$1" | head -n "$lineCount" | tr '\n' ' '
}

# join_lines TEXT [SEPARATOR]: TEXT on one line, each line followed by SEPARATOR (default a space).
join_lines() {
  printf '%s\n' "$1" | tr '\n' "${2:- }"
}
