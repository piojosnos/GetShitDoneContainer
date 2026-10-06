#!/usr/bin/env bash
# Self-test of the refresh on every start: edits and strays undone, renamed rules, removed skills, empty and duplicate list lines, list order, an interrupted sync.
# - Runs the hook on fixture bundles, changes the config folder or the bundle, runs it again and checks the result.
# - Each case builds its own fixture and config folders.
# - Run by run-all.sh; runs alone too.
# - Makes one work folder under TMPDIR and removes only that folder at exit.
# - Usage, from anywhere: bash tests/selftest/bundle/refresh.sh   (exit 0 = every case passes)
set -u
. "$(dirname "$0")/lib.sh"

# --------------------------------------------------------------------------------
# Edits synced rules and a bundle skill and places stray files, then runs the hook again
# --------------------------------------------------------------------------------
case_refresh() {
  echo "--- hand edits and stray files in rules/ and in a bundle skill are undone"
  fixture=$WORK/fixture-refresh
  make_bundle "$fixture" one.md sub/nested.md
  make_skill "$fixture" demo
  config=$WORK/config-refresh
  run_sync "$fixture" "$config" "$WORK/out.refresh1"
  expect "refresh: a nested rule is mirrored" files_equal "$fixture/rules/sub/nested.md" "$config/rules/sub/nested.md"
  echo "scribble" >>"$config/rules/one.md"
  echo "scribble" >>"$config/skills/demo/SKILL.md"
  echo "scribble" >"$config/skills/demo/notes/extra.md"
  plant "$config/rules/stray.md" "stray"
  plant "$config/rules/sub/stray-nested.md" "stray"
  run_sync "$fixture" "$config" "$WORK/out.refresh2"
  expect "refresh: the hook exits 0" equals "$SYNC_RC" "0"
  expect "refresh: an edited rule is restored" files_equal "$fixture/rules/one.md" "$config/rules/one.md"
  expect "refresh: a file placed by hand in rules/ is gone" test ! -e "$config/rules/stray.md"
  expect "refresh: a file placed by hand in a rules subfolder is gone" test ! -e "$config/rules/sub/stray-nested.md"
  expect "refresh: rules/ equals the bundle rules" trees_equal "$fixture/rules" "$config/rules"
  expect "refresh: an edited bundle skill is restored" trees_equal "$fixture/skills/demo" "$config/skills/demo"
}

# --------------------------------------------------------------------------------
# Renames a rule between two bundle versions
# --------------------------------------------------------------------------------
case_renamed_rule() {
  local fixtureV1 fixtureV2

  echo "--- a renamed rule leaves only the new name"
  fixtureV1=$WORK/fixture-rename-v1
  fixtureV2=$WORK/fixture-rename-v2
  make_bundle "$fixtureV1" old-name.md keep.md
  make_bundle "$fixtureV2" new-name.md keep.md
  config=$WORK/config-rename
  run_sync "$fixtureV1" "$config" "$WORK/out.rename1"
  expect "rename: the old name is there after the first start" test -f "$config/rules/old-name.md"
  run_sync "$fixtureV2" "$config" "$WORK/out.rename2"
  expect "rename: the hook exits 0" equals "$SYNC_RC" "0"
  expect "rename: the old name is gone" test ! -e "$config/rules/old-name.md"
  expect "rename: the new name is there" files_equal "$fixtureV2/rules/new-name.md" "$config/rules/new-name.md"
  expect "rename: rules/ equals the new bundle rules" trees_equal "$fixtureV2/rules" "$config/rules"
}

# --------------------------------------------------------------------------------
# Removes one of two skills between two bundle versions
# --------------------------------------------------------------------------------
case_removed_skill() {
  local fixtureV1 fixtureV2

  echo "--- a skill removed from the bundle is gone, the kept one stays listed"
  fixtureV1=$WORK/fixture-removal-v1
  fixtureV2=$WORK/fixture-removal-v2
  make_bundle "$fixtureV1" one.md
  make_skill "$fixtureV1" a-skill
  make_skill "$fixtureV1" b-skill
  make_bundle "$fixtureV2" one.md
  make_skill "$fixtureV2" a-skill
  config=$WORK/config-removal
  run_sync "$fixtureV1" "$config" "$WORK/out.removal1"
  expect "removal: both skills are there after the first start" test -d "$config/skills/b-skill"
  run_sync "$fixtureV2" "$config" "$WORK/out.removal2"
  expect "removal: the hook exits 0" equals "$SYNC_RC" "0"
  expect "removal: the removed skill is gone" test ! -e "$config/skills/b-skill"
  expect "removal: the kept skill equals the bundle" trees_equal "$fixtureV2/skills/a-skill" "$config/skills/a-skill"
  expect "removal: the list holds exactly a-skill" equals "$(cat "$config/.best-practices-skills")" "a-skill"
}

# --------------------------------------------------------------------------------
# Empties the bundle's skills folder after a first run
# --------------------------------------------------------------------------------
case_empty_skills_folder() {
  echo "--- an empty skills folder in the bundle empties the list and removes the listed skills"
  fixture=$WORK/fixture-emptyskills
  make_bundle "$fixture" one.md
  make_skill "$fixture" demo
  config=$WORK/config-emptyskills
  plant "$config/skills/my-own/SKILL.md" "mine"
  run_sync "$fixture" "$config" "$WORK/out.empty1"
  expect "empty: demo is installed first" test -d "$config/skills/demo"
  rm -rf "$fixture/skills/demo"
  run_sync "$fixture" "$config" "$WORK/out.empty2"
  expect "empty: the hook exits 0" equals "$SYNC_RC" "0"
  expect "empty: demo is removed" test ! -e "$config/skills/demo"
  expect "empty: the list file is empty" equals "$(wc -c <"$config/.best-practices-skills" | tr -d ' ')" "0"
  expect "empty: a user skill is untouched" equals "$(cat "$config/skills/my-own/SKILL.md")" "mine"
}

# --------------------------------------------------------------------------------
# Feeds the hook a list file with empty and repeated lines
# --------------------------------------------------------------------------------
case_duplicate_list_lines() {
  echo "--- empty and duplicate list lines are harmless"
  fixture=$WORK/fixture-duplicates
  make_bundle "$fixture" one.md
  make_skill "$fixture" demo
  config=$WORK/config-duplicates
  plant "$config/skills/demo/SKILL.md" "old demo"
  plant "$config/skills/my-own/SKILL.md" "mine"
  printf '%s\n' "demo" "" "demo" "" >"$config/.best-practices-skills"
  run_sync "$fixture" "$config" "$WORK/out.duplicates"
  expect "duplicates: the hook exits 0" equals "$SYNC_RC" "0"
  expect "duplicates: the skill equals the bundle" trees_equal "$fixture/skills/demo" "$config/skills/demo"
  expect "duplicates: the list holds demo once" equals "$(cat "$config/.best-practices-skills")" "demo"
  expect "duplicates: a user skill is untouched" equals "$(cat "$config/skills/my-own/SKILL.md")" "mine"
}

# --------------------------------------------------------------------------------
# Makes skill folders out of name order and checks the list order
# --------------------------------------------------------------------------------
case_list_order() {
  echo "--- the list is in name order, whatever order the folders were made in"
  fixture=$WORK/fixture-order
  make_bundle "$fixture" one.md
  make_skill "$fixture" b-skill
  make_skill "$fixture" a-skill
  make_skill "$fixture" c-skill
  config=$WORK/config-order
  run_sync "$fixture" "$config" "$WORK/out.order"
  printf '%s\n' "a-skill" "b-skill" "c-skill" >"$WORK/names.order"
  expect "order: the list reads a-skill, b-skill, c-skill" files_equal "$WORK/names.order" "$config/.best-practices-skills"
}

# --------------------------------------------------------------------------------
# Leaves a half-copied skill and no rules/, then runs the hook
# --------------------------------------------------------------------------------
case_interrupted_sync() {
  echo "--- an interrupted sync is fully repaired by the next run"
  fixture=$WORK/fixture-interrupted
  make_bundle "$fixture" one.md sub/nested.md
  make_skill "$fixture" demo
  config=$WORK/config-interrupted
  plant "$config/skills/demo/SKILL.md.part" "half a file"
  plant "$config/skills/my-own/SKILL.md" "mine"
  printf '%s\n' "demo" >"$config/.best-practices-skills"
  run_sync "$fixture" "$config" "$WORK/out.interrupted"
  expect "interrupted: the hook exits 0" equals "$SYNC_RC" "0"
  expect "interrupted: rules/ is back and equals the bundle" trees_equal "$fixture/rules" "$config/rules"
  expect "interrupted: the partly copied skill equals the bundle" trees_equal "$fixture/skills/demo" "$config/skills/demo"
  expect "interrupted: the partial file is gone" test ! -e "$config/skills/demo/SKILL.md.part"
  expect "interrupted: the list holds exactly demo" equals "$(cat "$config/.best-practices-skills")" "demo"
  expect "interrupted: a user skill is untouched" equals "$(cat "$config/skills/my-own/SKILL.md")" "mine"
}

# --------------------------------------------------------------------------------
# Main / Entry Point
# --------------------------------------------------------------------------------
require_no_arguments "$@" || exit 2
start_group || exit 1
case_refresh
case_renamed_rule
case_removed_skill
case_empty_skills_folder
case_duplicate_list_lines
case_list_order
case_interrupted_sync
finish_cases
