#!/usr/bin/env bash
# Self-test of the start hook against the repo bundle: first start, a second run that changes nothing, hand edits undone.
# - Syncs best-practices/ into a fresh config folder and checks rules, skills, the skill list and the user files beside them.
# - The three cases share the config folder and the names file, so they stay in this one file.
# - Run by run-all.sh; runs alone too.
# - Makes one work folder under TMPDIR and removes only that folder at exit.
# - Usage, from anywhere: bash tests/selftest/bundle/real-bundle.sh   (exit 0 = every case passes)
set -u
. "$(dirname "$0")/lib.sh"

# --------------------------------------------------------------------------------
# Runs the hook from the repo bundle into a fresh config folder
# --------------------------------------------------------------------------------
case_real_first_start() {
  local skillName

  echo "--- first start from the repo bundle"
  config=$WORK/real-config
  mkdir -p "$config/projects/demo/memory"
  echo "learned" >"$config/projects/demo/memory/note.md"
  echo "mine" >"$config/CLAUDE.md"
  echo "{}" >"$config/settings.json"
  run_sync "$BUNDLE" "$config" "$WORK/out.real"
  expect "real: the hook exits 0" equals "$SYNC_RC" "0"
  expect "real: the hook is silent on success" equals "$(wc -c <"$WORK/out.real" | tr -d ' ')" "0"
  expect "real: rules/ equals the bundle rules" trees_equal "$BUNDLE/rules" "$config/rules"
  bundle_skill_names >"$WORK/names.real"
  expect "real: the skill list equals the bundle skill names" files_equal "$WORK/names.real" "$config/.best-practices-skills"

  for skillName in $(bundle_skill_names); do
    expect "real: skill $skillName equals the bundle copy" trees_equal "$BUNDLE/skills/$skillName" "$config/skills/$skillName"
  done

  expect "real: memories are untouched" equals "$(cat "$config/projects/demo/memory/note.md")" "learned"
  expect "real: CLAUDE.md is untouched" equals "$(cat "$config/CLAUDE.md")" "mine"
  expect "real: settings.json is untouched" equals "$(cat "$config/settings.json")" "{}"
}

# --------------------------------------------------------------------------------
# Runs the hook a second time into the same config folder
# --------------------------------------------------------------------------------
case_real_second_run() {
  echo "--- second run changes nothing"
  run_sync "$BUNDLE" "$config" "$WORK/out.real2"
  expect "real again: the hook exits 0" equals "$SYNC_RC" "0"
  expect "real again: rules/ still equals the bundle rules" trees_equal "$BUNDLE/rules" "$config/rules"
  expect "real again: the skill list is the same" files_equal "$WORK/names.real" "$config/.best-practices-skills"
}

# --------------------------------------------------------------------------------
# Edits a synced rule and places a stray one, then runs the hook again
# --------------------------------------------------------------------------------
case_real_edits_undone() {
  echo "--- a hand edit and a hand-placed rule are undone"
  echo "scribble" >>"$config/rules/communication.md"
  echo "stray" >"$config/rules/stray.md"
  run_sync "$BUNDLE" "$config" "$WORK/out.real3"
  expect "edits: rules/ equals the bundle rules again" trees_equal "$BUNDLE/rules" "$config/rules"
}

# --------------------------------------------------------------------------------
# Main / Entry Point
# --------------------------------------------------------------------------------
require_no_arguments "$@" || exit 2
start_group || exit 1
case_real_first_start
case_real_second_run
case_real_edits_undone
finish_cases
