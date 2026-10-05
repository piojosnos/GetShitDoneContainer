#!/usr/bin/env bash
# Shared helpers for the attended checks in this folder: the terminal check, Claude in the test sandbox, y/N questions and the count of FAIL lines.
# - Sourced first by every helper here, before lib.sh, because the terminal check must run before host_init makes its first docker call.
# - Defines functions and one counter only. Its functions use lib.sh's functions and CONTAINER at call time, after the helper has loaded lib.sh.
# - It sits in this folder because it reads answers and opens claude with a terminal, which the unattended host tests never do.
# - Host side code is stock bash 3.2 with BSD tools (macOS).

# --------------------------------------------------------------------------------
# The terminal and Claude in the test sandbox
# --------------------------------------------------------------------------------

# require_terminal: exits 1 with a message when stdin or stdout is not a terminal.
require_terminal() {
  if [ ! -t 0 ] || [ ! -t 1 ]; then
    printf 'This helper needs a terminal. Run it directly, not through a pipe or a script.\n' >&2
    exit 1
  fi
}

# run_claude [ARG]: opens claude in the test sandbox, with ARG after it when one is given.
run_claude() {
  if [ "$#" -gt 0 ]; then
    docker exec -it -w /home/sandbox/workspace/hosttest "$CONTAINER" claude "$1"
  else
    docker exec -it -w /home/sandbox/workspace/hosttest "$CONTAINER" claude
  fi
}

# claude_logged_in TEXT: succeeds when TEXT, the output of claude auth status, shows "loggedIn": true.
claude_logged_in() {
  printf '%s\n' "$1" | grep -Eq '"loggedIn":[[:space:]]*true'
}

# --------------------------------------------------------------------------------
# Result lines and the exit code
# --------------------------------------------------------------------------------

# The number of FAIL result lines printed so far.
failCount=0

# count_result ID FAIL_SUMMARY PASS_TEXT: report_result, and adds one to failCount on FAIL.
count_result() {
  if ! report_result "$1" "$2" "$3"; then
    failCount=$((failCount + 1))
  fi
}

# ask_judgment ID QUESTION PASS_TEXT FAIL_TEXT: asks one y/N question; any answer but y or Y is a FAIL.
ask_judgment() {
  local answer

  printf '%s [y/N] ' "$2"
  read -r answer

  case "$answer" in
    y|Y)
      ;;
    *)
      add_problem "answer: ${answer:-<none>}"
      ;;
  esac

  count_result "$1" "$4" "$3"
}

# exit_with_result: exits 1 when any line was FAIL, else 0.
exit_with_result() {
  if [ "$failCount" -gt 0 ]; then
    exit 1
  fi

  exit 0
}
