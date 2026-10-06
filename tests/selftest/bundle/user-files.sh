#!/usr/bin/env bash
# Self-test of what the hook must never touch: user and GSD skills and files, a same-named user skill, shared name prefixes.
# - Checks user skills, GSD skills, settings, credentials and memories byte for byte across runs.
# - case_user_skill_clash and case_shared_prefix share the fixture, so they run in this order in this file.
# - Run by run-all.sh; runs alone too.
# - Makes one work folder under TMPDIR and removes only that folder at exit.
# - Usage, from anywhere: bash tests/selftest/bundle/user-files.sh   (exit 0 = every case passes)
set -u
. "$(dirname "$0")/lib.sh"

# --------------------------------------------------------------------------------
# Checks user skills, GSD skills and user files byte for byte across two runs
# --------------------------------------------------------------------------------
case_user_files() {
  local saved

  echo "--- user skills, GSD skills and user files are byte-identical after a run"
  fixture=$WORK/fixture-userfiles
  make_bundle "$fixture" one.md
  make_skill "$fixture" demo
  config=$WORK/config-userfiles
  saved=$WORK/saved-userfiles
  plant "$config/skills/my-own/SKILL.md" "my own skill"
  plant "$config/skills/my-own/notes/more.md" "more"
  plant "$config/skills/gsd-sample/SKILL.md" "gsd style skill"
  plant "$config/CLAUDE.md" "# my instructions"
  plant "$config/settings.json" '{"theme":"dark"}'
  plant "$config/.claude.json" '{"numStartups":3}'
  plant "$config/.credentials.json" '{"token":"secret"}'
  plant "$config/projects/p/memory/note.md" "learned note"
  plant "$config/projects/p/memory/MEMORY.md" "- [note](note.md)"
  cp -R "$config" "$saved"
  run_sync "$fixture" "$config" "$WORK/out.userfiles"
  expect "user files: the hook exits 0" equals "$SYNC_RC" "0"
  expect "user files: an unlisted user skill is byte-identical" trees_equal "$saved/skills/my-own" "$config/skills/my-own"
  expect "user files: a GSD-style skill is byte-identical" trees_equal "$saved/skills/gsd-sample" "$config/skills/gsd-sample"
  expect "user files: CLAUDE.md is byte-identical" files_equal "$saved/CLAUDE.md" "$config/CLAUDE.md"
  expect "user files: settings.json is byte-identical" files_equal "$saved/settings.json" "$config/settings.json"
  expect "user files: .claude.json is byte-identical" files_equal "$saved/.claude.json" "$config/.claude.json"
  expect "user files: .credentials.json is byte-identical" files_equal "$saved/.credentials.json" "$config/.credentials.json"
  expect "user files: a memory note is byte-identical" files_equal "$saved/projects/p/memory/note.md" "$config/projects/p/memory/note.md"
  expect "user files: MEMORY.md is byte-identical" files_equal "$saved/projects/p/memory/MEMORY.md" "$config/projects/p/memory/MEMORY.md"
  run_sync "$fixture" "$config" "$WORK/out.userfiles2"
  expect "user files: a second run keeps the memory note" files_equal "$saved/projects/p/memory/note.md" "$config/projects/p/memory/note.md"
  expect "user files: a second run keeps the user skill" trees_equal "$saved/skills/my-own" "$config/skills/my-own"
}

# --------------------------------------------------------------------------------
# Puts a user skill under a bundle skill's name before the first run
# --------------------------------------------------------------------------------
case_user_skill_clash() {
  echo "--- a user skill with a bundle skill's name is replaced and listed (no list file yet)"
  fixture=$WORK/fixture-clash
  make_bundle "$fixture" one.md
  make_skill "$fixture" demo
  config=$WORK/config-clash
  plant "$config/skills/demo/SKILL.md" "the user's own demo"
  plant "$config/skills/demo/private.md" "private"
  run_sync "$fixture" "$config" "$WORK/out.clash2"
  expect "clash: the hook exits 0 with no list file" equals "$SYNC_RC" "0"
  expect "clash: the bundle skill replaced the user skill" trees_equal "$fixture/skills/demo" "$config/skills/demo"
  expect "clash: nothing of the user skill is left" test ! -e "$config/skills/demo/private.md"
  expect "clash: the bundle skill is listed" equals "$(cat "$config/.best-practices-skills")" "demo"
}

# --------------------------------------------------------------------------------
# Keeps user skills whose names share a prefix with a bundle skill
# --------------------------------------------------------------------------------
case_shared_prefix() {
  local fixtureV2

  echo "--- user skills that share a prefix with a bundle skill survive"
  config=$WORK/config-prefix
  plant "$config/skills/dem/SKILL.md" "dem skill"
  plant "$config/skills/demo-extra/SKILL.md" "demo-extra skill"
  cp -R "$config/skills" "$WORK/saved-prefix"
  run_sync "$fixture" "$config" "$WORK/out.prefix1"
  run_sync "$fixture" "$config" "$WORK/out.prefix2"
  expect "prefix: dem survives two runs" trees_equal "$WORK/saved-prefix/dem" "$config/skills/dem"
  expect "prefix: demo-extra survives two runs" trees_equal "$WORK/saved-prefix/demo-extra" "$config/skills/demo-extra"
  expect "prefix: the bundle skill demo is there" trees_equal "$fixture/skills/demo" "$config/skills/demo"
  echo "demo" >"$WORK/names.prefix"
  expect "prefix: the list holds exactly demo" files_equal "$WORK/names.prefix" "$config/.best-practices-skills"
  fixtureV2=$WORK/fixture-prefix-gone
  make_bundle "$fixtureV2" one.md
  mkdir -p "$fixtureV2/skills"
  run_sync "$fixtureV2" "$config" "$WORK/out.prefix3"
  expect "prefix: removing demo from the bundle keeps dem" trees_equal "$WORK/saved-prefix/dem" "$config/skills/dem"
  expect "prefix: removing demo from the bundle keeps demo-extra" trees_equal "$WORK/saved-prefix/demo-extra" "$config/skills/demo-extra"
  expect "prefix: removing demo from the bundle removes demo" test ! -e "$config/skills/demo"
}

# --------------------------------------------------------------------------------
# Main / Entry Point
# --------------------------------------------------------------------------------
require_no_arguments "$@" || exit 2
start_group || exit 1
case_user_files
case_user_skill_clash
case_shared_prefix
finish_cases
