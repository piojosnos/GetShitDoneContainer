#!/usr/bin/env bash
# Self-test of the skill list: no skills folder, one skill, a dropped skill and a clash, hostile list lines.
# - Syncs fixture bundles and checks the skills folder and the list file the hook keeps.
# - case_one_skill, case_drop_and_clash and case_hostile_list_lines share the fixture and config folders,
#   so they run in this order in this file.
# - Run by run-all.sh; runs alone too.
# - Makes one work folder under TMPDIR and removes only that folder at exit.
# - Usage, from anywhere: bash tests/selftest/bundle/skill-lists.sh   (exit 0 = every case passes)
set -u
. "$(dirname "$0")/lib.sh"

# --------------------------------------------------------------------------------
# Syncs a bundle that has no skills folder
# --------------------------------------------------------------------------------
case_no_skills_folder() {
  echo "--- a bundle with no skills folder"
  fixture=$WORK/fixture-noskills
  mkdir -p "$fixture/rules"
  echo "rule" >"$fixture/rules/one.md"
  config=$WORK/config-noskills
  run_sync "$fixture" "$config" "$WORK/out.noskills"
  expect "no skills: the hook exits 0" equals "$SYNC_RC" "0"
  expect "no skills: skills/ exists and is empty" is_empty_dir "$config/skills"
  expect "no skills: the list file is empty" equals "$(wc -c <"$config/.best-practices-skills" | tr -d ' ')" "0"
  expect "no skills: the rule is copied" files_equal "$fixture/rules/one.md" "$config/rules/one.md"
}

# --------------------------------------------------------------------------------
# Syncs a bundle with one skill next to a user skill
# --------------------------------------------------------------------------------
case_one_skill() {
  echo "--- a bundle with one skill"
  fixture=$WORK/fixture-demo
  mkdir -p "$fixture/rules" "$fixture/skills/demo"
  echo "rule" >"$fixture/rules/one.md"
  echo "skill" >"$fixture/skills/demo/SKILL.md"
  config=$WORK/config-demo
  mkdir -p "$config/skills/own"
  echo "mine" >"$config/skills/own/SKILL.md"
  run_sync "$fixture" "$config" "$WORK/out.demo"
  expect "demo: the hook exits 0" equals "$SYNC_RC" "0"
  expect "demo: skills/demo equals the fixture" trees_equal "$fixture/skills/demo" "$config/skills/demo"
  expect "demo: the list holds exactly demo" equals "$(cat "$config/.best-practices-skills")" "demo"
  expect "demo: an unlisted skill is untouched" equals "$(cat "$config/skills/own/SKILL.md")" "mine"
}

# --------------------------------------------------------------------------------
# Drops a skill from the bundle, adds another, then clashes with it
# --------------------------------------------------------------------------------
case_drop_and_clash() {
  echo "--- a skill dropped from the bundle disappears, a clash is won by the bundle"
  echo "edited" >"$config/skills/demo/SKILL.md"
  rm -rf "$fixture/skills/demo"
  mkdir -p "$fixture/skills/other"
  echo "other" >"$fixture/skills/other/SKILL.md"
  run_sync "$fixture" "$config" "$WORK/out.drop"
  expect "drop: the old skill is gone" test ! -e "$config/skills/demo"
  expect "drop: the new skill is there" equals "$(cat "$config/skills/other/SKILL.md")" "other"
  expect "drop: the list holds exactly other" equals "$(cat "$config/.best-practices-skills")" "other"
  expect "drop: an unlisted skill is untouched" equals "$(cat "$config/skills/own/SKILL.md")" "mine"
  echo "clash" >"$config/skills/other/SKILL.md"
  run_sync "$fixture" "$config" "$WORK/out.clash"
  expect "clash: the bundle skill wins" equals "$(cat "$config/skills/other/SKILL.md")" "other"
}

# --------------------------------------------------------------------------------
# Feeds the hook a list file with hostile lines
# --------------------------------------------------------------------------------
case_hostile_list_lines() {
  echo "--- hostile list lines"
  config=$WORK/config-hostile
  mkdir -p "$config/projects/demo/memory" "$config/skills/.hidden" "$config/skills/a/b" "$config/skills/old-skill" "$config/skills/keep"
  echo "learned" >"$config/projects/demo/memory/note.md"
  echo "x" >"$config/skills/.hidden/file"
  echo "x" >"$config/skills/a/b/file"
  echo "x" >"$config/skills/old-skill/file"
  echo "x" >"$config/skills/keep/file"
  printf '%s\n' "../projects" ".hidden" "" "/etc" "a/b" "old-skill" >"$config/.best-practices-skills"
  run_sync "$fixture" "$config" "$WORK/out.hostile"
  expect "hostile: the hook exits 0" equals "$SYNC_RC" "0"
  expect "hostile: memories survive" equals "$(cat "$config/projects/demo/memory/note.md")" "learned"
  expect "hostile: a dot folder survives" test -f "$config/skills/.hidden/file"
  expect "hostile: a nested folder survives" test -f "$config/skills/a/b/file"
  expect "hostile: an unlisted skill survives" test -f "$config/skills/keep/file"
  expect "hostile: the legitimately listed skill is removed" test ! -e "$config/skills/old-skill"
}

# --------------------------------------------------------------------------------
# Main / Entry Point
# --------------------------------------------------------------------------------
require_no_arguments "$@" || exit 2
start_group || exit 1
case_no_skills_folder
case_one_skill
case_drop_and_clash
case_hostile_list_lines
finish_cases
