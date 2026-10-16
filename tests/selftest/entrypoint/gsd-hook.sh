#!/usr/bin/env bash
# ------------------------------------------------------------------------------
# Self-test of claude/start.d/05-gsd against a fake GSD
# ------------------------------------------------------------------------------
# Usage: bash tests/selftest/entrypoint/gsd-hook.sh (exit 0 = all pass)
# Run by run-all.sh; its one work folder under TMPDIR is removed at exit.
# ------------------------------------------------------------------------------
set -u
. "$(dirname "$0")/lib.sh"

# ------------------------------------------------------------------------------
# install_fake_gsd: puts the fake first on PATH as gsd-core and gsd-tools
# ------------------------------------------------------------------------------
install_fake_gsd() {
  mkdir -p "$WORK/bin" || return 1
  cp "$REPO/tests/selftest/entrypoint/support/fake-gsd" "$WORK/bin/gsd-core" || return 1
  cp "$REPO/tests/selftest/entrypoint/support/fake-gsd" "$WORK/bin/gsd-tools" || return 1
  chmod +x "$WORK/bin/gsd-core" "$WORK/bin/gsd-tools" || return 1

  export PATH="$WORK/bin:$PATH"
  export FAKE_REPO="$REPO"
}

# ------------------------------------------------------------------------------
# run_gsd_hook CONFIG_DIR NAME [VAR=VALUE...]: runs the hook, sets HOOK_RC
# ------------------------------------------------------------------------------
# Output goes to WORK/NAME.out and NAME.err, installer calls to NAME.gsdlog.
# ------------------------------------------------------------------------------
run_gsd_hook() {
  local configDir=$1
  local name=$2

  shift 2
  env CLAUDE_CONFIG_DIR="$configDir" FAKE_GSD_LOG="$WORK/$name.gsdlog" "$@" \
    bash "$REPO/claude/start.d/05-gsd" >"$WORK/$name.out" 2>"$WORK/$name.err" </dev/null
  HOOK_RC=$?
}

# ------------------------------------------------------------------------------
# Case: the first sync prints one line, hides the installer and makes the folder
# ------------------------------------------------------------------------------
case_first_sync() {
  local pin

  pin=$(pin_of GSD_CORE_VERSION)

  echo '--- the first sync'
  run_gsd_hook "$WORK/sync/cfg" sync

  expect "gsd hook: a sync exits 0 and prints one line naming the pinned version" equals "$HOOK_RC:$(cat "$WORK/sync.out")" "0:[sbx] GSD $pin synced"
  expect "gsd hook: the sync prints nothing on stderr" test ! -s "$WORK/sync.err"
  expect "gsd hook: the installer banner is not on stdout" lacks_text "$WORK/sync.out" "GSD fake installer banner"
  expect "gsd hook: the installer banner is not on stderr" lacks_text "$WORK/sync.err" "GSD fake installer banner"
  expect "gsd hook: the installer gets the config folder" has_text "$WORK/sync.gsdlog" "--claude --global --config-dir $WORK/sync/cfg"
  expect "gsd hook: a missing config folder is made" test -f "$WORK/sync/cfg/gsd-core/VERSION"
}

# ------------------------------------------------------------------------------
# Case: a failing installer stops the start and shows its output
# ------------------------------------------------------------------------------
case_failing_installer_stops() {
  echo '--- a failing installer stops the start'
  run_gsd_hook "$WORK/failing/cfg" failing FAKE_GSD_FAIL=1

  expect "gsd hook: a failing installer stops the start and shows its output" equals "$HOOK_RC" 1
  expect "gsd hook: the installer's own text is shown" has_text "$WORK/failing.err" "fake gsd: install failed on purpose"
  expect "gsd hook: the error names the failed sync" has_text "$WORK/failing.err" "[sbx] ERROR: the GSD sync into $WORK/failing/cfg failed"
}

# ------------------------------------------------------------------------------
# Case: a config folder that cannot be made stops at once, without the installer
# ------------------------------------------------------------------------------
case_unmakeable_folder_stops() {
  echo '--- a config folder that cannot be made stops at once'
  run_gsd_hook /proc/no-such-dir unmakeable

  expect "gsd hook: a config folder that cannot be made stops at once without the installer" equals "$HOOK_RC" 1
  expect "gsd hook: the error says the folder cannot be created" has_text "$WORK/unmakeable.err" "cannot create the Claude config folder"
  expect "gsd hook: the installer never ran" test ! -e "$WORK/unmakeable.gsdlog"
}

# ------------------------------------------------------------------------------
# Case: a synced version that differs from the image stops the start
# ------------------------------------------------------------------------------
case_version_mismatch_stops() {
  local pin

  pin=$(pin_of GSD_CORE_VERSION)

  echo '--- a synced version that differs from the image stops the start'
  run_gsd_hook "$WORK/mismatch/cfg" mismatch FAKE_GSD_VERSION=0.0.0

  expect "gsd hook: a synced version that differs from the image stops the start" equals "$HOOK_RC" 1
  expect "gsd hook: the error names both versions" has_text "$WORK/mismatch.err" "[sbx] ERROR: GSD in $WORK/mismatch/cfg is version '0.0.0'; the image has '$pin'."
}

# ------------------------------------------------------------------------------
# Main / Entry Point
# ------------------------------------------------------------------------------
require_no_arguments "$@" || exit 2
start_group || exit 1
install_fake_gsd || exit 1
case_first_sync
case_failing_installer_stops
case_unmakeable_folder_stops
case_version_mismatch_stops
finish_cases
