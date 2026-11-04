#!/usr/bin/env bash
# ------------------------------------------------------------------------------
# Self-test of claude/start.d/10-best-practices in a temp sandbox folder
# ------------------------------------------------------------------------------
# Usage: bash tests/selftest/entrypoint/bundle-hook.sh (exit 0 = all pass)
# ------------------------------------------------------------------------------
set -u
. "$(dirname "$0")/lib.sh"

# ------------------------------------------------------------------------------
# make_clone FOLDER: makes a clone with one rule and the skills sbx-one, sbx-two
# ------------------------------------------------------------------------------
make_clone() {
  mkdir -p "$1/rules" "$1/skills/sbx-one" "$1/skills/sbx-two" || return 1
  printf '# Always\n\nsbx-always-rule\n' >"$1/rules/sbx-always.md"
  printf -- '---\nname: test\ndescription: A test skill.\n---\n' | tee "$1/skills/sbx-one/SKILL.md" >"$1/skills/sbx-two/SKILL.md"
}

# ------------------------------------------------------------------------------
# new_sandbox NAME: sets WS and CONFIG, makes a clone in WS/best-practices
# ------------------------------------------------------------------------------
new_sandbox() {
  WS=$WORK/$1
  CONFIG=$WS/state/claude
  make_clone "$WS/best-practices"
}

# ------------------------------------------------------------------------------
# run_bundle_hook WS NAME [BUNDLE_DIR]: runs the hook, sets HOOK_RC
# ------------------------------------------------------------------------------
run_bundle_hook() {
  mkdir -p "$1/state/claude"
  env CLAUDE_CONFIG_DIR="$1/state/claude" SBX_BUNDLE_DIR="${3:-$1/best-practices}" bash "$REPO/claude/start.d/10-best-practices" >"$WORK/$2.out" 2>"$WORK/$2.err" </dev/null
  HOOK_RC=$?
}

# ------------------------------------------------------------------------------
# config_tree: prints the names under CONFIG, links not followed, on one line
# ------------------------------------------------------------------------------
config_tree() {
  find "$CONFIG" -mindepth 1 | sed "s|^$CONFIG/||" | LC_ALL=C sort | tr '\n' ' '
}

# ------------------------------------------------------------------------------
# Case: links, the same list on a rerun, and nothing written into the clone
# ------------------------------------------------------------------------------
case_links_and_rerun() {
  echo '--- links and a rerun'
  new_sandbox links
  run_bundle_hook "$WS" links
  expect "bundle hook: rules is a link to ../../best-practices/rules" equals "$(readlink "$CONFIG/rules")" ../../best-practices/rules
  expect "bundle hook: each skill is a link into the clone" equals "$(readlink "$CONFIG/skills/sbx-one") $(readlink "$CONFIG/skills/sbx-two")" "../../../best-practices/skills/sbx-one ../../../best-practices/skills/sbx-two"
  expect "bundle hook: the skill list names the clone's skills" equals "$(cat "$CONFIG/.best-practices-skills")" "$(printf 'sbx-one\nsbx-two')"
  cp -R "$WS/best-practices" "$WS/clone-before" && cp "$CONFIG/.best-practices-skills" "$WS/list-before"
  run_bundle_hook "$WS" links-again
  expect "bundle hook: a rerun keeps the same skill list" cmp -s "$WS/list-before" "$CONFIG/.best-practices-skills"
  expect "bundle hook: a rerun leaves no link inside the clone" equals "$(find "$WS/best-practices" -type l)" ""
  expect "bundle hook: a rerun leaves the clone's files as they were" equals "$(diff -r "$WS/best-practices" "$WS/clone-before")" ""
}

# ------------------------------------------------------------------------------
# Case: copies from an older start become links, other skills stay
# ------------------------------------------------------------------------------
case_upgrade_from_copies() {
  echo '--- an upgrade from copies'
  new_sandbox upgrade
  mkdir -p "$CONFIG/rules" "$CONFIG/skills/sbx-one" "$CONFIG/skills/my-own" "$CONFIG/skills/gsd-sample"
  echo stale >"$CONFIG/rules/stale.md"
  echo sbx-one >"$CONFIG/.best-practices-skills"
  echo kept | tee "$CONFIG/skills/my-own/SKILL.md" "$CONFIG/skills/gsd-sample/SKILL.md" >"$CONFIG/skills/sbx-one/SKILL.md"
  run_bundle_hook "$WS" upgrade
  expect "bundle hook: copied rules from an older start become a link" equals "$(test -L "$CONFIG/rules" && echo link)$(test -e "$CONFIG/rules/stale.md" && echo stale)" link
  expect "bundle hook: a copied bundle skill becomes a link" test -L "$CONFIG/skills/sbx-one"
  expect "bundle hook: the user and GSD skills survive the upgrade" equals "$(cat "$CONFIG"/skills/my-own/SKILL.md "$CONFIG"/skills/gsd-sample/SKILL.md)" "$(printf 'kept\nkept')"
}

# ------------------------------------------------------------------------------
# Case: a skill dropped from the clone loses its link and its list entry
# ------------------------------------------------------------------------------
case_dropped_skill() {
  echo '--- a dropped skill'
  new_sandbox dropped
  run_bundle_hook "$WS" dropped-first
  mv "$WS/best-practices/skills/sbx-two" "$WS/sbx-two-moved"
  run_bundle_hook "$WS" dropped
  expect "bundle hook: a skill dropped from the clone loses its link and list entry" equals "$(config_tree)" ".best-practices-skills rules skills skills/sbx-one "
}

# ------------------------------------------------------------------------------
# Case: no clone, or a folder without rules/, starts fine and removes old links
# ------------------------------------------------------------------------------
case_no_clone() {
  local oneLine

  echo '--- no clone'
  new_sandbox noclone
  oneLine="[sbx] no best-practices clone at $WS/best-practices; run sbx-bundle-clone"
  run_bundle_hook "$WS" noclone-first
  mkdir -p "$CONFIG/skills/my-own" "$CONFIG/skills/gsd-sample"
  echo kept | tee "$CONFIG/skills/my-own/SKILL.md" >"$CONFIG/skills/gsd-sample/SKILL.md"
  mv "$WS/best-practices" "$WS/clone-moved"
  run_bundle_hook "$WS" noclone
  expect "bundle hook: no clone: exits 0 with one line naming sbx-bundle-clone" equals "$HOOK_RC:$(cat "$WORK/noclone.out")" "0:$oneLine"
  expect "bundle hook: no clone: the earlier links are gone" equals "$(config_tree)" "skills skills/gsd-sample skills/gsd-sample/SKILL.md skills/my-own skills/my-own/SKILL.md "
  expect "bundle hook: no clone: the user and GSD skills are untouched" equals "$(cat "$CONFIG"/skills/my-own/SKILL.md "$CONFIG"/skills/gsd-sample/SKILL.md)" "$(printf 'kept\nkept')"
  mkdir -p "$WS/best-practices"
  run_bundle_hook "$WS" emptyclone
  expect "bundle hook: a folder without rules/ counts as no clone" equals "$HOOK_RC:$(cat "$WORK/emptyclone.out")" "0:$oneLine"
}

# ------------------------------------------------------------------------------
# Case: a clone with rules/ and no skills/ links rules and lists nothing
# ------------------------------------------------------------------------------
case_clone_without_skills() {
  echo '--- a clone without skills'
  new_sandbox noskills
  rm -rf "$WS/best-practices/skills"
  run_bundle_hook "$WS" noskills
  expect "bundle hook: a clone with no skills links rules and lists nothing" equals "$HOOK_RC:$(test -L "$CONFIG/rules" && echo link):$(wc -c <"$CONFIG/.best-practices-skills" | tr -d ' ')" "0:link:0"
}

# ------------------------------------------------------------------------------
# Case: empty inputs and a clone the links cannot reach stop the start
# ------------------------------------------------------------------------------
case_bad_inputs() {
  echo '--- bad inputs'
  new_sandbox badinputs
  env CLAUDE_CONFIG_DIR= SBX_BUNDLE_DIR="$WS/best-practices" bash "$REPO/claude/start.d/10-best-practices" >/dev/null 2>"$WORK/noconfig.err" </dev/null; HOOK_RC=$?
  expect "bundle hook: an empty CLAUDE_CONFIG_DIR stops the start" equals "$HOOK_RC:$(grep -Fc '[sbx] ERROR:' "$WORK/noconfig.err")" "1:1"
  env CLAUDE_CONFIG_DIR="$CONFIG" SBX_BUNDLE_DIR= bash "$REPO/claude/start.d/10-best-practices" >/dev/null 2>"$WORK/nobundle.err" </dev/null; HOOK_RC=$?
  expect "bundle hook: an empty SBX_BUNDLE_DIR stops the start" equals "$HOOK_RC:$(grep -Fc '[sbx] ERROR:' "$WORK/nobundle.err")" "1:1"
  make_clone "$WORK/elsewhere"
  run_bundle_hook "$WS" unreachable "$WORK/elsewhere"
  expect "bundle hook: a clone the links cannot reach stops the start" equals "$HOOK_RC:$(grep -Fc 'does not resolve to' "$WORK/unreachable.err")" "1:1"
}

# ------------------------------------------------------------------------------
# Main / Entry Point
# ------------------------------------------------------------------------------
require_no_arguments "$@" || exit 2
start_group || exit 1
case_links_and_rerun
case_upgrade_from_copies
case_dropped_skill
case_no_clone
case_clone_without_skills
case_bad_inputs
finish_cases
