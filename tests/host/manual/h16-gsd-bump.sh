#!/usr/bin/env bash
# ------------------------------------------------------------------------------
# H-16 helper: a GSD pin bump reaches a logged-in sandbox; the session survives
# ------------------------------------------------------------------------------
# Usage: bash tests/host/manual/h16-gsd-bump.sh (exit 0 = PASS)
# It never edits a file; once the pin changed it prints how to put it back.
# ------------------------------------------------------------------------------
set -u

. "$(dirname "$0")/lib-manual.sh"
require_terminal

. "$(dirname "$0")/../lib.sh"
host_init

oldPin=""
newPin=""

# ------------------------------------------------------------------------------
# Checks the test sandbox holds a Claude login; FAIL and return 1 if not
# ------------------------------------------------------------------------------
check_logged_in() {
  if add_login_problem "run bash tests/host/manual/h07-login.sh first"; then
    return 0
  fi

  report_result H-16 "the test sandbox has no Claude login to carry through the bump" \
    'claude auth status shows "loggedIn": true before the bump'

  return 1
}

# ------------------------------------------------------------------------------
# Waits while you change GSD_CORE_VERSION; FAIL and return 1 if it is unchanged
# ------------------------------------------------------------------------------
wait_for_pin_change() {
  local answer

  oldPin=$(pin_of GSD_CORE_VERSION)
  printf '\nGSD is pinned at %s in versions.env.\n' "$oldPin"
  printf 'In another terminal, change GSD_CORE_VERSION in %s/versions.env to the version you approved as the bump target.\n' "$REPO_DIR"
  printf 'Press Enter here when it is saved. '
  read -r answer
  newPin=$(pin_of GSD_CORE_VERSION)

  if [ -z "$newPin" ] || [ "$newPin" = "$oldPin" ]; then
    fail H-16 "versions.env still pins GSD $oldPin; nothing to bump"

    return 1
  fi

  return 0
}

# ------------------------------------------------------------------------------
# Rebuilds both images with the new pin; FAIL and return 1 if the build fails
# ------------------------------------------------------------------------------
rebuild_images() {
  info "rebuilding sbx-base:local and sbx-claude:local with GSD $newPin (logs in $RUN/logs)"

  if ! build_images manual-gsd-bump; then
    fail H-16 "the image rebuild failed"

    return 1
  fi
}

# ------------------------------------------------------------------------------
# Checks state/claude, gsd-tools and the start log show the new GSD
# ------------------------------------------------------------------------------
# The start log must show no npx and no @latest either.
# ------------------------------------------------------------------------------
check_bumped_gsd() {
  local syncedVersion=""
  local identityText startLog

  if [ -f "$RUN/state/claude/gsd-core/VERSION" ]; then
    syncedVersion=$(cat "$RUN/state/claude/gsd-core/VERSION")
  fi

  if [ "$syncedVersion" != "$newPin" ]; then
    add_problem "state/claude/gsd-core/VERSION is '$syncedVersion'; the new pin is $newPin"
  fi

  identityText=$(in_container gsd-tools runtime-identity --raw | tr -d ' ')

  if ! printf '%s\n' "$identityText" | grep -Fq "\"version\":\"$newPin\""; then
    add_problem "gsd-tools runtime-identity does not report version $newPin: $(first_lines "$identityText")"
  fi

  startLog=$(docker logs "$CONTAINER" 2>&1 </dev/null)

  if ! printf '%s\n' "$startLog" | grep -Fq "[sbx] GSD $newPin synced"; then
    add_problem "the start log does not hold: [sbx] GSD $newPin synced"
  fi

  if printf '%s\n' "$startLog" | grep -Eq 'npx|@latest'; then
    add_problem "the start log names npx or @latest; a start must use only the GSD in the image"
  fi

  count_result H-16 "GSD did not move to the new pin" \
    "GSD $newPin is in state/claude and in the start log, with no npx and no @latest"
}

# ------------------------------------------------------------------------------
# Checks claude auth status still says logged in
# ------------------------------------------------------------------------------
check_still_logged_in() {
  add_login_problem "if you have not logged in yet, run bash tests/host/manual/h07-login.sh first"
  count_result H-16 "claude auth status does not show a login after the GSD bump" \
    'claude auth status still shows "loggedIn": true after the GSD bump'
}

# ------------------------------------------------------------------------------
# Opens claude --continue and asks whether the earlier session resumed
# ------------------------------------------------------------------------------
resume_session() {
  printf '\nClaude opens next with claude --continue.\n'
  printf '  Look for: the session from the login helper is picked up again (earlier messages shown).\n'
  printf '  Type /exit to come back here.\n\n'
  run_claude --continue
  printf '\n'
  ask_judgment H-16 "Did the earlier session resume?" \
    "claude --continue resumed the earlier session" \
    "claude --continue did not resume the earlier session"
}

# ------------------------------------------------------------------------------
# Prints how to put the old pin back; runs on exit once the change was seen
# ------------------------------------------------------------------------------
# It names the recorded old pin, not a discard of the file, so other edits stay.
# ------------------------------------------------------------------------------
print_restore_steps() {
  printf '\nThe images may now hold GSD %s.\n' "$newPin"
  printf 'Before your own sandboxes start again, set GSD_CORE_VERSION in %s/versions.env back to %s and rebuild:\n' "$REPO_DIR" "$oldPin"
  printf '  ./build.sh\n'
}

# ------------------------------------------------------------------------------
# Main / Entry Point
# ------------------------------------------------------------------------------
require_no_arguments "$@" || exit 2
require_test_sandbox H-16 || exit 1
check_logged_in || exit 1
wait_for_pin_change || exit 1
trap print_restore_steps EXIT
rebuild_images || exit 1
restart_test_sandbox H-16 manual-gsd-down.log || exit 1
require_test_sandbox H-16 || exit 1
check_bumped_gsd
check_still_logged_in
resume_session
exit_with_result
