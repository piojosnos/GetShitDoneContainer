#!/usr/bin/env bash
# ------------------------------------------------------------------------------
# H-16: a restart refreshes the bundle and GSD and spares the user files
# ------------------------------------------------------------------------------
# Needs: test sandbox running; stops and restarts it
# Planted files are left in the run folder for the printed cleanup.
# ------------------------------------------------------------------------------
set -u
. "$(dirname "$0")/lib.sh"
. "$(dirname "$0")/lib-bundle.sh"
host_init

bundleDir=$REPO_DIR/best-practices
syncedDir=$RUN/state/claude
memoryDir=$syncedDir/projects/-home-sandbox-workspace-hosttest/memory
sentinelText="h16-$$-$(date +%s)"
sessionFile=$syncedDir/projects/-home-sandbox-workspace-hosttest/h16-session.jsonl
settingsScript='const fs = require("fs"); const file = process.env.CLAUDE_CONFIG_DIR + "/settings.json"; let settings = {}; if (fs.existsSync(file)) { settings = JSON.parse(fs.readFileSync(file, "utf8")); } settings.h16Sentinel = process.argv[1]; fs.writeFileSync(file, JSON.stringify(settings, null, 2) + "\n");'

# ------------------------------------------------------------------------------
# Picks the first bundle skill, always-on rule and GSD skill to edit
# ------------------------------------------------------------------------------
pick_samples() {
  local ruleFileList ruleFile gsdSkillPath

  firstSkill=$(bundle_skill_names | sed -n 1p)

  firstRule=""
  ruleFileList=$(cd "$bundleDir/rules" && find . -maxdepth 1 -type f -name '*.md' | sed 's|^\./||' | sort)

  for ruleFile in $ruleFileList; do
    if [ -z "$firstRule" ] && [ "$(sed -n 1p "$bundleDir/rules/$ruleFile")" != "---" ]; then
      firstRule=$ruleFile
    fi
  done

  if [ -z "$firstSkill" ] || [ -z "$firstRule" ]; then
    fail H-16 "the repo bundle has no always-on rule or no skill to edit" "looked in $bundleDir"
    return 1
  fi

  gsdSkillPath=$(find "$syncedDir/skills" -maxdepth 1 -type d -name 'gsd-*' 2>/dev/null | sort | sed -n 1p)

  if [ -z "$gsdSkillPath" ]; then
    fail H-16 "state/claude has no skills/gsd-* folder; GSD never synced" "looked in $syncedDir/skills"
    return 1
  fi

  firstGsdSkill=$(basename "$gsdSkillPath")
}

# ------------------------------------------------------------------------------
# Plants stale and user files, edits a synced rule and skill, ages GSD
# ------------------------------------------------------------------------------
# User files: a skill, memory, session, CLAUDE.md and a settings.json key (set
# by node in the container). No gsd-* skill is planted; GSD owns that name.
# ------------------------------------------------------------------------------
plant_files() {
  local plantOutput

  mkdir -p "$syncedDir/rules" "$syncedDir/skills/h16-old-bundle-skill" "$syncedDir/skills/h16-user-skill" \
    "$syncedDir/skills/$firstSkill" "$syncedDir/gsd-core" "$memoryDir"

  printf '%s\n' "$sentinelText" >"$syncedDir/rules/h16-stale.md"
  printf '%s\n' "$sentinelText" >"$syncedDir/skills/h16-old-bundle-skill/SKILL.md"
  printf '%s\n' "h16-old-bundle-skill" >>"$syncedDir/.best-practices-skills"
  printf '%s\n' "$sentinelText" >"$syncedDir/skills/h16-user-skill/SKILL.md"
  printf '%s\n' "$sentinelText" >"$memoryDir/h16-memory.md"
  printf '# %s\n' "$sentinelText" >"$syncedDir/CLAUDE.md"
  printf 'h16 hand edit\n' >>"$syncedDir/rules/$firstRule"
  printf 'h16 hand edit\n' >>"$syncedDir/skills/$firstSkill/SKILL.md"
  printf '%s\n' "$sentinelText" >"$sessionFile"
  printf '0.0.0' >"$syncedDir/gsd-core/VERSION"
  printf 'h16 hand edit\n' >>"$syncedDir/skills/$firstGsdSkill/SKILL.md"

  if ! plantOutput=$(in_container node -e "$settingsScript" "$sentinelText"); then
    add_problem "could not plant the settings key: $(first_lines "$plantOutput")"
  fi
}

# ------------------------------------------------------------------------------
# Checks the stale rule and the old bundle skill are gone
# ------------------------------------------------------------------------------
check_stale_files_gone() {
  if [ -e "$syncedDir/rules/h16-stale.md" ]; then
    add_problem "state/claude/rules/h16-stale.md is still there after the restart"
  fi

  if [ -e "$syncedDir/skills/h16-old-bundle-skill" ]; then
    add_problem "state/claude/skills/h16-old-bundle-skill is still there after the restart"
  fi
}

# ------------------------------------------------------------------------------
# Checks GSD is back at the pin and the hand edit in the GSD skill is undone
# ------------------------------------------------------------------------------
check_gsd_refreshed() {
  local pinnedVersion syncedVersion=""

  pinnedVersion=$(pin_of GSD_CORE_VERSION)

  if [ -f "$syncedDir/gsd-core/VERSION" ]; then
    syncedVersion=$(cat "$syncedDir/gsd-core/VERSION")
  fi

  if [ "$syncedVersion" != "$pinnedVersion" ]; then
    add_problem "state/claude/gsd-core/VERSION is '$syncedVersion' after the restart; the image has GSD $pinnedVersion"
  fi

  if [ ! -f "$syncedDir/skills/$firstGsdSkill/SKILL.md" ]; then
    add_problem "state/claude/skills/$firstGsdSkill/SKILL.md is missing after the restart"
  elif grep -Fq "h16 hand edit" "$syncedDir/skills/$firstGsdSkill/SKILL.md"; then
    add_problem "state/claude/skills/$firstGsdSkill still has the hand edit after the restart"
  fi
}

# ------------------------------------------------------------------------------
# Checks every planted user file still holds its sentinel
# ------------------------------------------------------------------------------
check_user_files_spared() {
  local userFile

  for userFile in "$syncedDir/skills/h16-user-skill/SKILL.md" "$memoryDir/h16-memory.md" "$sessionFile" \
    "$syncedDir/settings.json" "$syncedDir/CLAUDE.md"; do
    if ! grep -Fq "$sentinelText" "$userFile" 2>/dev/null; then
      add_problem "${userFile#"$RUN"/} is missing or changed after the restart"
    fi
  done
}

# ------------------------------------------------------------------------------
# Main / Entry Point
# ------------------------------------------------------------------------------
require_no_arguments "$@" || exit 2
require_test_sandbox H-16 || exit 1
pick_samples || exit 1
plant_files
restart_test_sandbox H-16 h16-down.log || exit 1
check_stale_files_gone
check_gsd_refreshed
check_bundle_skill_list "$syncedDir"
check_user_files_spared
check_bundle_rules_synced "$syncedDir"
check_bundle_skills_synced "$syncedDir"
report_check H-16 "the restart did not refresh the bundle and GSD or did not spare the user's files" \
  "a restart removed the stale rule and skill, restored edited copies and GSD at the pin, and kept the user's skills, memories, sessions, settings key and CLAUDE.md"
