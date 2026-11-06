#!/usr/bin/env bash
# ------------------------------------------------------------------------------
# H-29 helper: sbx-upgrade keeps the Claude login and the session
# ------------------------------------------------------------------------------
# Usage: bash tests/host/manual/h29-upgrade-resume.sh [--no-cache]
# Needs a terminal. It logs in to Claude itself, in its own registered sandbox
# folder, so it needs no earlier login. Exit 0 = PASS.
# ------------------------------------------------------------------------------
set -u

. "$(dirname "$0")/lib-manual.sh"
require_terminal

. "$(dirname "$0")/../lib.sh"
host_init
. "$(dirname "$0")/../lib-sbx.sh"

noCacheFlag=""
sbxDir=""
sbxPath=""
sbxStatus=0

# ------------------------------------------------------------------------------
# Reads the arguments: only --no-cache is allowed; else usage and return 1
# ------------------------------------------------------------------------------
parse_arguments() {
  while [ "$#" -gt 0 ]; do
    case "$1" in
      --no-cache)
        noCacheFlag="--no-cache"
        ;;
      *)
        print_usage "[--no-cache]"
        return 1
        ;;
    esac

    shift
  done

  if [ "${SBXTEST_NO_CACHE:-}" = "1" ]; then
    noCacheFlag="--no-cache"
  fi

  return 0
}

# ------------------------------------------------------------------------------
# Registers and starts the helper's own sandbox; FAIL and return 1 if it fails
# ------------------------------------------------------------------------------
prepare() {
  require_test_sandbox H-29 || return 1
  sbx_test_setup H-29 h29m || return 1

  if ! compose_down >"$RUN/logs/h29m-down.log" 2>&1; then
    fail H-29 "compose down failed before the helper; log: $RUN/logs/h29m-down.log"
    return 1
  fi

  run_sbx h29m-add sbx-add hosttest "$sbxDir"

  if [ "$sbxStatus" -ne 0 ]; then
    fail H-29 "sbx-add exited $sbxStatus; log: $RUN/logs/h29m-add.err"
    restore_test_sandbox h29m
    return 1
  fi

  run_sbx h29m-start sbx-start hosttest

  if [ "$sbxStatus" -ne 0 ]; then
    fail H-29 "sbx-start exited $sbxStatus; log: $RUN/logs/h29m-start.err"
    restore_test_sandbox h29m
    return 1
  fi
}

# ------------------------------------------------------------------------------
# Opens Claude for the login, then checks that claude auth status shows it
# ------------------------------------------------------------------------------
log_in() {
  printf '\nClaude opens next in the helper sandbox.\n'
  printf '  Log in with a claude.ai account, send one message, then type /exit.\n\n'
  run_claude
  printf '\n'
  add_login_problem
  count_result H-29 "claude auth status shows no login in the helper's sandbox" \
    'claude auth status shows "loggedIn": true'
}

# ------------------------------------------------------------------------------
# Runs sbx-upgrade, with --no-cache only when it was asked for
# ------------------------------------------------------------------------------
upgrade() {
  info "running sbx-upgrade hosttest ${noCacheFlag}; logs in $RUN/logs/h29m-upgrade.*"

  if [ -n "$noCacheFlag" ]; then
    run_sbx h29m-upgrade sbx-upgrade hosttest "$noCacheFlag"
  else
    run_sbx h29m-upgrade sbx-upgrade hosttest
  fi

  if [ "$sbxStatus" -ne 0 ]; then
    add_problem "sbx-upgrade exited $sbxStatus; last lines of the error log:"
    add_problem "$(print_log_tail "$RUN/logs/h29m-upgrade.err")"
  fi

  count_result H-29 "sbx-upgrade failed" \
    "sbx-upgrade rebuilt and recreated the helper's sandbox"
}

# ------------------------------------------------------------------------------
# Checks the login survived, then opens claude --continue and asks about it
# ------------------------------------------------------------------------------
check_login_and_resume() {
  add_login_problem
  count_result H-29 "claude auth status does not show a login after sbx-upgrade" \
    'claude auth status still shows "loggedIn": true after sbx-upgrade'

  printf '\nClaude opens next with claude --continue.\n'
  printf '  Look for: the message you sent earlier is shown again.\n'
  printf '  Type /exit to come back here.\n\n'
  run_claude --continue
  printf '\n'
  ask_judgment H-29 "Did the earlier session resume?" \
    "claude --continue resumed the earlier session after sbx-upgrade" \
    "claude --continue did not resume the earlier session"
}

# ------------------------------------------------------------------------------
# Puts the test sandbox back on the run folder
# ------------------------------------------------------------------------------
restore() {
  restore_test_sandbox h29m
  count_result H-29 "the test sandbox did not come back on the run folder" \
    "the test sandbox runs on the run folder again"
  printf 'The run folder now also holds the Claude login of this helper.\n'
  printf 'The cleanup command that run-all.sh printed removes it.\n'
}

# ------------------------------------------------------------------------------
# Main / Entry Point
# ------------------------------------------------------------------------------
parse_arguments "$@" || exit 2
prepare || exit 1
log_in
upgrade
check_login_and_resume
restore
exit_with_result
