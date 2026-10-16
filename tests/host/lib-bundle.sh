#!/usr/bin/env bash
# ------------------------------------------------------------------------------
# Shared bundle checks for the host tests: is a synced config the bundle's
# ------------------------------------------------------------------------------
# Sourced after lib.sh by the checks that need it; runs nothing.
# Each check takes a synced config folder (state/claude), reports by add_problem
# ------------------------------------------------------------------------------

# ------------------------------------------------------------------------------
# bundle_skill_names: the bundle's skill names, one per line
# ------------------------------------------------------------------------------
bundle_skill_names() {
  local skillDir

  for skillDir in "$REPO_DIR"/best-practices/skills/*/; do
    if [ -d "$skillDir" ]; then
      basename "$skillDir"
    fi
  done
}

# ------------------------------------------------------------------------------
# check_bundle_rules_synced CONFIG_DIR [PROBLEM_TEXT]: rules must match bundle
# ------------------------------------------------------------------------------
# PROBLEM_TEXT starts the message; the first lines of the diff follow it.
check_bundle_rules_synced() {
  local configDir=$1
  local problemText=${2:-state/claude/rules differs from best-practices/rules}
  local rulesDiff

  rulesDiff=$(diff -r -x .DS_Store "$REPO_DIR/best-practices/rules" "$configDir/rules" 2>&1)

  if [ "$?" -ne 0 ]; then
    add_problem "$problemText: $(first_lines "$rulesDiff")"
  fi
}

# ------------------------------------------------------------------------------
# check_bundle_skills_synced CONFIG_DIR: each bundle skill must equal its copy
# ------------------------------------------------------------------------------
check_bundle_skills_synced() {
  local configDir=$1
  local skillDir skillName skillDiff

  for skillDir in "$REPO_DIR"/best-practices/skills/*/; do
    if [ ! -d "$skillDir" ]; then
      continue
    fi

    skillName=$(basename "$skillDir")
    skillDiff=$(diff -r -x .DS_Store "$skillDir" "$configDir/skills/$skillName" 2>&1)

    if [ "$?" -ne 0 ]; then
      add_problem "state/claude/skills/$skillName differs from best-practices/skills/$skillName: $(first_lines "$skillDiff")"
    fi
  done
}

# ------------------------------------------------------------------------------
# check_bundle_skill_list CONFIG_DIR: the skill list must be the bundle's skills
# ------------------------------------------------------------------------------
check_bundle_skill_list() {
  local configDir=$1
  local expectedList actualList

  expectedList=$(bundle_skill_names)
  actualList=$(cat "$configDir/.best-practices-skills" 2>/dev/null)

  if [ "$actualList" != "$expectedList" ]; then
    add_problem "state/claude/.best-practices-skills lists '$(printf '%s' "$actualList" | tr '\n' ' ')'; the bundle has '$(printf '%s' "$expectedList" | tr '\n' ' ')'"
  fi
}
