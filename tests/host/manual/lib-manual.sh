#!/usr/bin/env bash
# ------------------------------------------------------------------------------
# Shared helpers for the attended checks: terminal, Claude, y/N questions
# ------------------------------------------------------------------------------
# Sourced first by every helper here, before lib.sh; runs nothing by itself.
# The terminal check must run before host_init makes its first docker call.
# ------------------------------------------------------------------------------

# ------------------------------------------------------------------------------
# require_terminal: exits 1 unless stdin and stdout are a terminal
# ------------------------------------------------------------------------------
require_terminal() {
  if [ ! -t 0 ] || [ ! -t 1 ]; then
    printf 'This helper needs a terminal. Run it directly, not through a pipe or a script.\n' >&2
    exit 1
  fi
}

# ------------------------------------------------------------------------------
# run_claude [ARG]: opens claude in the test sandbox, with ARG when given
# ------------------------------------------------------------------------------
run_claude() {
  if [ "$#" -gt 0 ]; then
    docker exec -it -w /home/sandbox/workspace/hosttest "$CONTAINER" claude "$1"
  else
    docker exec -it -w /home/sandbox/workspace/hosttest "$CONTAINER" claude
  fi
}

# ------------------------------------------------------------------------------
# add_login_problem [HINT]: adds problems unless claude shows a login
# ------------------------------------------------------------------------------
# Looks for "loggedIn": true in claude auth status; returns 1 when it is absent.
# ------------------------------------------------------------------------------
add_login_problem() {
  local authOutput

  authOutput=$(in_container claude auth status)

  if printf '%s\n' "$authOutput" | grep -Eq '"loggedIn":[[:space:]]*true'; then
    return 0
  fi

  add_problem "got: $(first_lines "$authOutput")"

  if [ "$#" -gt 0 ]; then
    add_problem "$1"
  fi

  return 1
}

# ------------------------------------------------------------------------------
# failCount: the number of FAIL result lines printed so far
# ------------------------------------------------------------------------------
failCount=0

# ------------------------------------------------------------------------------
# count_result ID FAIL_SUMMARY PASS_TEXT: report_result; counts a FAIL
# ------------------------------------------------------------------------------
count_result() {
  if ! report_result "$1" "$2" "$3"; then
    failCount=$((failCount + 1))
  fi
}

# ------------------------------------------------------------------------------
# ask_judgment ID QUESTION PASS_TEXT FAIL_TEXT: asks one y/N question
# ------------------------------------------------------------------------------
# Any answer but y or Y is a FAIL.
# ------------------------------------------------------------------------------
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

# ------------------------------------------------------------------------------
# exit_with_result: exits 1 when any line was FAIL, else 0
# ------------------------------------------------------------------------------
exit_with_result() {
  if [ "$failCount" -gt 0 ]; then
    exit 1
  fi

  exit 0
}
