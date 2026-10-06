#!/usr/bin/env bash
# H-16: a restart refreshes the bundle from the image and leaves the user's skills, memories and CLAUDE.md alone.
# - Before the restart the check plants files in state/claude: a stale rule, a skill an older image
#   installed (simulated by a name in the list file with no bundle folder), a user skill, a GSD-style
#   skill, a memory and a CLAUDE.md. It also edits one synced rule and one synced bundle skill.
# - The restart is the same down and up as H-08, and runs the start hook in the real image.
# - After it, the stale rule and the old skill must be gone, the edits undone, and every user file
#   unchanged. Planted files are left in the run folder for the printed cleanup.
# Depends on: nothing
# Needs: test sandbox running; stops and restarts it
set -u
. "$(dirname "$0")/lib.sh"
. "$(dirname "$0")/lib-bundle.sh"
host_init

bundleDir=$REPO_DIR/best-practices
syncedDir=$RUN/state/claude
memoryDir=$syncedDir/projects/-home-sandbox-workspace-hosttest/memory
sentinelText="h16-$$-$(date +%s)"

# --------------------------------------------------------------------------------
# Picks the first bundle skill and the first always-on rule to edit; FAIL and return 1 if there is none
# --------------------------------------------------------------------------------
pick_samples() {
  local ruleFileList ruleFile

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
}

# --------------------------------------------------------------------------------
# Plants the stale and user files in state/claude and edits one synced rule and skill
# --------------------------------------------------------------------------------
plant_files() {
  mkdir -p "$syncedDir/rules" "$syncedDir/skills/h16-old-bundle-skill" "$syncedDir/skills/h16-user-skill" \
    "$syncedDir/skills/gsd-h16-sample" "$syncedDir/skills/$firstSkill" "$memoryDir"

  printf '%s\n' "$sentinelText" >"$syncedDir/rules/h16-stale.md"
  printf '%s\n' "$sentinelText" >"$syncedDir/skills/h16-old-bundle-skill/SKILL.md"
  printf '%s\n' "h16-old-bundle-skill" >>"$syncedDir/.best-practices-skills"
  printf '%s\n' "$sentinelText" >"$syncedDir/skills/h16-user-skill/SKILL.md"
  printf '%s\n' "$sentinelText" >"$syncedDir/skills/gsd-h16-sample/SKILL.md"
  printf '%s\n' "$sentinelText" >"$memoryDir/h16-memory.md"
  printf '# %s\n' "$sentinelText" >"$syncedDir/CLAUDE.md"
  printf 'h16 hand edit\n' >>"$syncedDir/rules/$firstRule"
  printf 'h16 hand edit\n' >>"$syncedDir/skills/$firstSkill/SKILL.md"
}

# --------------------------------------------------------------------------------
# Checks the stale rule and the old bundle skill are gone
# --------------------------------------------------------------------------------
check_stale_files_gone() {
  if [ -e "$syncedDir/rules/h16-stale.md" ]; then
    add_problem "state/claude/rules/h16-stale.md is still there after the restart"
  fi

  if [ -e "$syncedDir/skills/h16-old-bundle-skill" ]; then
    add_problem "state/claude/skills/h16-old-bundle-skill is still there after the restart"
  fi
}

# --------------------------------------------------------------------------------
# Checks every planted user file still holds its sentinel
# --------------------------------------------------------------------------------
check_user_files_spared() {
  local userFile

  for userFile in "$syncedDir/skills/h16-user-skill/SKILL.md" "$syncedDir/skills/gsd-h16-sample/SKILL.md" \
    "$memoryDir/h16-memory.md" "$syncedDir/CLAUDE.md"; do
    if ! grep -Fq "$sentinelText" "$userFile" 2>/dev/null; then
      add_problem "${userFile#"$RUN"/} is missing or changed after the restart"
    fi
  done
}

# --------------------------------------------------------------------------------
# Main / Entry Point
# --------------------------------------------------------------------------------
require_no_arguments "$@" || exit 2
require_test_sandbox H-16 || exit 1
pick_samples || exit 1
plant_files
restart_test_sandbox H-16 h16-down.log || exit 1
check_stale_files_gone
check_bundle_skill_list "$syncedDir"
check_user_files_spared
check_bundle_rules_synced "$syncedDir"
check_bundle_skills_synced "$syncedDir"
report_check H-16 "the restart did not refresh the bundle or did not spare the user's files" \
  "a restart removed the stale rule and skill, restored edited copies, and kept user skills, GSD skills, memories and CLAUDE.md"
