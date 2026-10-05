#!/usr/bin/env bash
# H-09 (attended): rebuild the images, recreate the test sandbox, and confirm the login and the
# earlier Claude session survive.
# - Needs a terminal. Run it after bash tests/host/manual/h07-login.sh, against the same test
#   sandbox (sbx-hosttest). It finds the run folder from the container's mount.
# - Steps: rebuild sbx-base:local and sbx-claude:local (the real tags), take the sandbox down,
#   bring it up, check claude auth status is still logged in, open claude --continue, then ask you
#   whether the earlier session resumed. Nothing is deleted; the folders and the images stay.
# - Slow clean rebuild: pass --no-cache, or set SBXTEST_NO_CACHE=1.
# - Usage: bash tests/host/manual/h09-rebuild-resume.sh [--no-cache]   (exit 0 = PASS)
set -u

. "$(dirname "$0")/lib-manual.sh"
require_terminal

. "$(dirname "$0")/../lib.sh"
host_init

noCacheFlag=""

# --------------------------------------------------------------------------------
# Reads the optional --no-cache argument; prints the usage and exits 2 on anything else
# --------------------------------------------------------------------------------
parse_arguments() {
  case "$1" in
    0) ;;
    1)
      if [ "$2" = "--no-cache" ]; then
        noCacheFlag="--no-cache"
      else
        printf 'Usage: bash tests/host/manual/h09-rebuild-resume.sh [--no-cache]\n' >&2
        exit 2
      fi
      ;;
    *)
      printf 'Usage: bash tests/host/manual/h09-rebuild-resume.sh [--no-cache]\n' >&2
      exit 2
      ;;
  esac

  if [ "${SBXTEST_NO_CACHE:-}" = "1" ]; then
    noCacheFlag="--no-cache"
  fi
}

# --------------------------------------------------------------------------------
# Rebuilds both images; stops if the build fails
# --------------------------------------------------------------------------------
rebuild_images() {
  info "rebuilding sbx-base:local and sbx-claude:local (logs in $RUN/logs)"

  if ! build_images manual-rebuild "$noCacheFlag"; then
    stop_check H-09 "the image rebuild failed"
  fi
}

# --------------------------------------------------------------------------------
# Takes the test sandbox down and up again; stops if either fails
# --------------------------------------------------------------------------------
recreate_sandbox() {
  info "taking the test sandbox down"

  if ! compose_down >"$RUN/logs/manual-down.log" 2>&1; then
    stop_check H-09 "compose down failed" "log: $RUN/logs/manual-down.log"
  fi

  info "starting the test sandbox"

  if ! compose_up; then
    stop_check H-09 "compose up failed after the rebuild" "log: $RUN/logs/compose-up.log"
  fi

  require_test_sandbox H-09 || exit 1
}

# --------------------------------------------------------------------------------
# Checks claude auth status still says logged in; stops if not
# --------------------------------------------------------------------------------
check_still_logged_in() {
  local authOutput

  authOutput=$(in_container claude auth status)

  if ! claude_logged_in "$authOutput"; then
    add_problem "got: $(first_lines "$authOutput")"
    add_problem "if you have not logged in yet, run bash tests/host/manual/h07-login.sh first"
  fi

  report_result H-09 "claude auth status does not show a login after the rebuild" \
    'claude auth status still shows "loggedIn": true after the rebuild' || exit 1
}

# --------------------------------------------------------------------------------
# Opens claude --continue and asks whether the earlier session resumed
# --------------------------------------------------------------------------------
resume_session() {
  printf '\nClaude opens next with claude --continue.\n'
  printf '  Look for: the session from the login helper is picked up again (earlier messages shown).\n'
  printf '  Type /exit to come back here.\n\n'
  run_claude --continue
  printf '\n'
  ask_judgment H-09 "Did the earlier session resume?" \
    "claude --continue resumed the earlier session" \
    "claude --continue did not resume the earlier session"
}

# --------------------------------------------------------------------------------
# Main / Entry Point
# --------------------------------------------------------------------------------
parse_arguments "$#" "${1:-}"
require_test_sandbox H-09 || exit 1
rebuild_images
recreate_sandbox
check_still_logged_in
resume_session
exit_with_result
