#!/usr/bin/env bash
# Self-test of claude/start.d/05-gsd against the fake GSD in tests/selftest/host/support/fake-gsd.
# - Proves the success line, the hidden installer output, the fail-closed stops, the stop before the
#   installer when the config folder cannot be made, the version check and the bundle winning a name clash.
# - Run by run-all.sh; runs alone too.
# - Makes one work folder under TMPDIR and removes only that folder at exit.
# - Linux only, in the dev sandbox.
# - Usage, from anywhere: bash tests/selftest/entrypoint/gsd-hook.sh   (exit 0 = every case passes)
set -u
. "$(dirname "$0")/lib.sh"

# --------------------------------------------------------------------------------
# install_fake_gsd: installs the fake as WORK/bin/gsd-core and WORK/bin/gsd-tools, puts WORK/bin first on PATH and exports FAKE_REPO; returns 1 on failure.
# --------------------------------------------------------------------------------
install_fake_gsd() {
  mkdir -p "$WORK/bin" || return 1
  cp "$REPO/tests/selftest/host/support/fake-gsd" "$WORK/bin/gsd-core" || return 1
  cp "$REPO/tests/selftest/host/support/fake-gsd" "$WORK/bin/gsd-tools" || return 1
  chmod +x "$WORK/bin/gsd-core" "$WORK/bin/gsd-tools" || return 1

  export PATH="$WORK/bin:$PATH"
  export FAKE_REPO="$REPO"
}

# --------------------------------------------------------------------------------
# run_gsd_hook CONFIG_DIR NAME [VAR=VALUE...]: runs the hook with stdin closed; output goes to WORK/NAME.out and WORK/NAME.err; sets HOOK_RC.
# --------------------------------------------------------------------------------
run_gsd_hook() {
  local configDir=$1
  local name=$2

  shift 2
  env CLAUDE_CONFIG_DIR="$configDir" FAKE_GSD_LOG="$WORK/$name.gsdlog" "$@" \
    bash "$REPO/claude/start.d/05-gsd" >"$WORK/$name.out" 2>"$WORK/$name.err" </dev/null
  HOOK_RC=$?
}

# --------------------------------------------------------------------------------
# Case: a sync exits 0 and prints one line naming the pinned version
# --------------------------------------------------------------------------------
case_sync_prints_one_line() {
  local pin

  pin=$(pin_of GSD_CORE_VERSION)

  echo '--- a sync prints one line'
  run_gsd_hook "$WORK/sync/cfg" sync

  expect "gsd hook: a sync exits 0 and prints one line naming the pinned version" equals "$HOOK_RC:$(cat "$WORK/sync.out")" "0:[sbx] GSD $pin synced"
  expect "gsd hook: the sync prints nothing on stderr" test ! -s "$WORK/sync.err"
}

# --------------------------------------------------------------------------------
# Case: the installer output stays hidden after a sync
# --------------------------------------------------------------------------------
case_installer_output_hidden() {
  echo '--- the installer output stays hidden'

  expect "gsd hook: the installer output stays hidden after a sync" lacks_text "$WORK/sync.out" "GSD fake installer banner"
  expect "gsd hook: the installer banner is not on stderr either" lacks_text "$WORK/sync.err" "GSD fake installer banner"
}

# --------------------------------------------------------------------------------
# Case: the installer gets the config folder
# --------------------------------------------------------------------------------
case_installer_gets_config_folder() {
  echo '--- the installer gets the config folder'

  expect "gsd hook: the installer gets the config folder" has_text "$WORK/sync.gsdlog" "--claude --global --config-dir $WORK/sync/cfg"
}

# --------------------------------------------------------------------------------
# Case: a missing config folder is made
# --------------------------------------------------------------------------------
case_missing_config_folder_made() {
  echo '--- a missing config folder is made'

  expect "gsd hook: a missing config folder is made" test -f "$WORK/sync/cfg/gsd-core/VERSION"
}

# --------------------------------------------------------------------------------
# Case: a failing installer stops the start and shows its output
# --------------------------------------------------------------------------------
case_failing_installer_stops() {
  echo '--- a failing installer stops the start'
  run_gsd_hook "$WORK/failing/cfg" failing FAKE_GSD_FAIL=1

  expect "gsd hook: a failing installer stops the start and shows its output" equals "$HOOK_RC" 1
  expect "gsd hook: the installer's own text is shown" has_text "$WORK/failing.err" "fake gsd: install failed on purpose"
  expect "gsd hook: the error names the failed sync" has_text "$WORK/failing.err" "[sbx] ERROR: the GSD sync into $WORK/failing/cfg failed"
}

# --------------------------------------------------------------------------------
# Case: a config folder that cannot be made stops at once, without the installer
# --------------------------------------------------------------------------------
case_unmakeable_folder_stops() {
  echo '--- a config folder that cannot be made stops at once'
  run_gsd_hook /proc/no-such-dir unmakeable

  expect "gsd hook: a config folder that cannot be made stops at once without the installer" equals "$HOOK_RC" 1
  expect "gsd hook: the error says the folder cannot be created" has_text "$WORK/unmakeable.err" "cannot create the Claude config folder"
  expect "gsd hook: the installer never ran" test ! -e "$WORK/unmakeable.gsdlog"
}

# --------------------------------------------------------------------------------
# Case: an empty CLAUDE_CONFIG_DIR stops the start
# --------------------------------------------------------------------------------
case_empty_config_dir_stops() {
  echo '--- an empty CLAUDE_CONFIG_DIR stops the start'
  run_gsd_hook "" empty

  expect "gsd hook: an empty CLAUDE_CONFIG_DIR stops the start" equals "$HOOK_RC" 1
  expect "gsd hook: the error says the variable is not set" has_text "$WORK/empty.err" "CLAUDE_CONFIG_DIR is not set"
}

# --------------------------------------------------------------------------------
# Case: a synced version that differs from the image stops the start
# --------------------------------------------------------------------------------
case_version_mismatch_stops() {
  local pin

  pin=$(pin_of GSD_CORE_VERSION)

  echo '--- a synced version that differs from the image stops the start'
  run_gsd_hook "$WORK/mismatch/cfg" mismatch FAKE_GSD_VERSION=0.0.0

  expect "gsd hook: a synced version that differs from the image stops the start" equals "$HOOK_RC" 1
  expect "gsd hook: the error names both versions" has_text "$WORK/mismatch.err" "[sbx] ERROR: GSD in $WORK/mismatch/cfg is version '0.0.0'; the image has '$pin'."
}

# --------------------------------------------------------------------------------
# Case: the bundle hook runs after it, so a bundle skill wins a name clash
# --------------------------------------------------------------------------------
case_bundle_wins_name_clash() {
  local configDir=$WORK/clash/cfg

  echo '--- the bundle wins a name clash'
  mkdir -p "$configDir"

  (
    export CLAUDE_CONFIG_DIR=$configDir SBX_BUNDLE_DIR=$REPO/best-practices FAKE_GSD_CLASH=pr-reply
    . "$START_LIB"
    hookDir=$REPO/claude/start.d
    run_start_hooks
  ) >"$WORK/clash.out" 2>&1 </dev/null

  expect "gsd hook: the bundle hook runs after it, so a bundle skill wins a name clash" diff -rq "$configDir/skills/pr-reply" "$REPO/best-practices/skills/pr-reply"
  expect "gsd hook: the other GSD skill stays" test -f "$configDir/skills/gsd-fake-skill/SKILL.md"
}

# --------------------------------------------------------------------------------
# Main / Entry Point
# --------------------------------------------------------------------------------
require_no_arguments "$@" || exit 2
start_group || exit 1
install_fake_gsd || exit 1
case_sync_prints_one_line
case_installer_output_hidden
case_installer_gets_config_folder
case_missing_config_folder_made
case_failing_installer_stops
case_unmakeable_folder_stops
case_empty_config_dir_stops
case_version_mismatch_stops
case_bundle_wins_name_clash
finish_cases
