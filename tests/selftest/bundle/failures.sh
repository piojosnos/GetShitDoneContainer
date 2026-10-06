#!/usr/bin/env bash
# Self-test of the start hook failures: a missing bundle, no config folder, a config folder that cannot be written.
# - Checks the exit status, the [sbx] ERROR line and that nothing is changed or written.
# - The locked-config case is skipped as root, where a folder mode cannot block a write.
# - Run by run-all.sh; runs alone too.
# - Makes one work folder under TMPDIR and removes only that folder at exit.
# - Usage, from anywhere: bash tests/selftest/bundle/failures.sh   (exit 0 = every case passes)
set -u
. "$(dirname "$0")/lib.sh"

# --------------------------------------------------------------------------------
# Points the hook at a bundle that does not exist
# --------------------------------------------------------------------------------
case_missing_bundle() {
  echo "--- a missing bundle"
  config=$WORK/config-missing
  mkdir -p "$config/rules"
  echo "keep" >"$config/rules/keep.md"
  run_sync "$WORK/no-such-bundle" "$config" "$WORK/out.missing"
  expect "missing: the hook exits non-zero" test "$SYNC_RC" -ne 0
  expect "missing: the output has an [sbx] ERROR line" has_text "$WORK/out.missing" "[sbx] ERROR"
  expect "missing: the existing rules are untouched" equals "$(cat "$config/rules/keep.md")" "keep"
}

# --------------------------------------------------------------------------------
# Runs the hook with no CLAUDE_CONFIG_DIR
# --------------------------------------------------------------------------------
case_no_config_folder() {
  local noConfigRc

  echo "--- no config folder"
  env -u CLAUDE_CONFIG_DIR SBX_BUNDLE_DIR="$BUNDLE" bash "$HOOK" >"$WORK/out.noconfig" 2>&1 </dev/null
  noConfigRc=$?
  expect "no config: the hook exits non-zero" test "$noConfigRc" -ne 0
  expect "no config: the output names CLAUDE_CONFIG_DIR" has_text "$WORK/out.noconfig" "[sbx] ERROR: CLAUDE_CONFIG_DIR is not set."
}

# --------------------------------------------------------------------------------
# Makes the small bundle the locked-config case syncs from
# --------------------------------------------------------------------------------
prepare_locked_fixture() {
  fixture=$WORK/fixture-locked
  make_bundle "$fixture" one.md
}

# --------------------------------------------------------------------------------
# Runs the hook into a config folder that cannot be written; skipped as root
# --------------------------------------------------------------------------------
case_locked_config() {
  echo "--- a config folder that cannot be written"
  config=$WORK/config-locked
  mkdir -p "$config"

  if [ "$(id -u)" = "0" ]; then
    echo "SKIP: unwritable config folder (running as root)"
  else
    chmod 555 "$config"
    run_sync "$fixture" "$config" "$WORK/out.locked"
    chmod 755 "$config"
    expect "locked: the hook exits non-zero" test "$SYNC_RC" -ne 0
    expect "locked: nothing was written" is_empty_dir "$config"
  fi
}

# --------------------------------------------------------------------------------
# Main / Entry Point
# --------------------------------------------------------------------------------
require_no_arguments "$@" || exit 2
start_group || exit 1
case_missing_bundle
case_no_config_folder
prepare_locked_fixture
case_locked_config
finish_cases
