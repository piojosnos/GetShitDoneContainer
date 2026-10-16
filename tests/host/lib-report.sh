#!/usr/bin/env bash
# ------------------------------------------------------------------------------
# Reporting for the host tests: PASS, FAIL and INFO lines, a check's result
# ------------------------------------------------------------------------------
# Sourced by tests/host/lib.sh; runs nothing.
# A check calls add_problem per failed assertion, then ends with report_check.
# ------------------------------------------------------------------------------

# ------------------------------------------------------------------------------
# pass ID TEXT: prints one PASS line
# ------------------------------------------------------------------------------
pass() {
  printf 'PASS: %s %s\n' "$1" "$2"
}

# ------------------------------------------------------------------------------
# fail ID TEXT [DETAIL...]: prints one FAIL line, then each detail indented
# ------------------------------------------------------------------------------
# For a step that voids the rest of a check; the caller stops with || exit 1.
# ------------------------------------------------------------------------------
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

# ------------------------------------------------------------------------------
# info TEXT: prints one INFO line
# ------------------------------------------------------------------------------
info() {
  printf 'INFO: %s\n' "$1"
}

# ------------------------------------------------------------------------------
# problemList: every message add_problem collected, in the order added
# ------------------------------------------------------------------------------
problemList=()

# ------------------------------------------------------------------------------
# add_problem MESSAGE: keeps MESSAGE for report_check to print as a FAIL detail
# ------------------------------------------------------------------------------
add_problem() {
  problemList+=("$1")
}

# ------------------------------------------------------------------------------
# report_result ID FAIL_SUMMARY PASS_TEXT: FAIL plus all problems, else PASS
# ------------------------------------------------------------------------------
# Returns 1 on FAIL and empties the list. Also for multi-result helpers.
# The count is tested first: bash 3.2 and set -u call an empty array unbound.
# ------------------------------------------------------------------------------
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

# ------------------------------------------------------------------------------
# report_check ID FAIL_SUMMARY PASS_TEXT: report_result, then exit 1 or 0
# ------------------------------------------------------------------------------
report_check() {
  if report_result "$@"; then
    exit 0
  fi

  exit 1
}

# ------------------------------------------------------------------------------
# print_log_tail FILE: prints the last 20 lines of FILE, indented four spaces
# ------------------------------------------------------------------------------
print_log_tail() {
  tail -n 20 "$1" | sed 's/^/    /'
}

# ------------------------------------------------------------------------------
# first_lines TEXT [COUNT]: the first COUNT (default 3) lines on one line
# ------------------------------------------------------------------------------
first_lines() {
  local lineCount=${2:-3}

  printf '%s\n' "$1" | head -n "$lineCount" | tr '\n' ' '
}

# ------------------------------------------------------------------------------
# join_lines TEXT [SEPARATOR]: TEXT on one line, SEPARATOR after each line
# ------------------------------------------------------------------------------
# SEPARATOR defaults to a space.
# ------------------------------------------------------------------------------
# ------------------------------------------------------------------------------
join_lines() {
  printf '%s\n' "$1" | tr '\n' "${2:- }"
}
