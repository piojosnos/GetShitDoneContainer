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
host_init
require_test_sandbox H-16 || exit 1

bundleDir=$REPO_DIR/best-practices
syncedDir=$RUN/state/claude
memoryDir=$syncedDir/projects/-home-sandbox-workspace-hosttest/memory
sentinelText="h16-$$-$(date +%s)"

bundleSkillList=""
for skillDir in "$bundleDir"/skills/*/; do
  if [ -d "$skillDir" ]; then
    bundleSkillList="$bundleSkillList$(basename "$skillDir")
"
  fi
done
firstSkill=$(printf '%s' "$bundleSkillList" | sed -n 1p)

firstRule=""
ruleFileList=$(cd "$bundleDir/rules" && find . -maxdepth 1 -type f -name '*.md' | sed 's|^\./||' | sort)
for ruleFile in $ruleFileList; do
  if [ -z "$firstRule" ] && [ "$(sed -n 1p "$bundleDir/rules/$ruleFile")" != "---" ]; then
    firstRule=$ruleFile
  fi
done

if [ -z "$firstSkill" ] || [ -z "$firstRule" ]; then
  fail H-16 "the repo bundle has no always-on rule or no skill to edit" "looked in $bundleDir"
  exit 1
fi

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

if ! compose_down >"$RUN/logs/h16-down.log" 2>&1; then
  fail H-16 "compose down failed" "log: $RUN/logs/h16-down.log"
  exit 1
fi

if ! compose_up; then
  fail H-16 "compose up failed after the down" "log: $RUN/logs/compose-up.log"
  exit 1
fi

set --

if [ -e "$syncedDir/rules/h16-stale.md" ]; then
  set -- "$@" "state/claude/rules/h16-stale.md is still there after the restart"
fi

if [ -e "$syncedDir/skills/h16-old-bundle-skill" ]; then
  set -- "$@" "state/claude/skills/h16-old-bundle-skill is still there after the restart"
fi

expectedList=$(printf '%s' "$bundleSkillList")
actualList=$(cat "$syncedDir/.best-practices-skills" 2>/dev/null)
if [ "$actualList" != "$expectedList" ]; then
  set -- "$@" "state/claude/.best-practices-skills lists '$(printf '%s' "$actualList" | tr '\n' ' ')'; the bundle has '$(printf '%s' "$expectedList" | tr '\n' ' ')'"
fi

for userFile in "$syncedDir/skills/h16-user-skill/SKILL.md" "$syncedDir/skills/gsd-h16-sample/SKILL.md" \
  "$memoryDir/h16-memory.md" "$syncedDir/CLAUDE.md"; do
  if ! grep -Fq "$sentinelText" "$userFile" 2>/dev/null; then
    set -- "$@" "${userFile#"$RUN"/} is missing or changed after the restart"
  fi
done

rulesDiff=$(diff -r -x .DS_Store "$bundleDir/rules" "$syncedDir/rules" 2>&1)
if [ "$?" -ne 0 ]; then
  set -- "$@" "state/claude/rules differs from best-practices/rules: $(printf '%s\n' "$rulesDiff" | head -n 3 | tr '\n' ' ')"
fi

for skillDir in "$bundleDir"/skills/*/; do
  if [ ! -d "$skillDir" ]; then
    continue
  fi

  skillName=$(basename "$skillDir")
  skillDiff=$(diff -r -x .DS_Store "$skillDir" "$syncedDir/skills/$skillName" 2>&1)
  if [ "$?" -ne 0 ]; then
    set -- "$@" "state/claude/skills/$skillName differs from best-practices/skills/$skillName: $(printf '%s\n' "$skillDiff" | head -n 3 | tr '\n' ' ')"
  fi
done

if [ "$#" -gt 0 ]; then
  fail H-16 "the restart did not refresh the bundle or did not spare the user's files" "$@"
  exit 1
fi

pass H-16 "a restart removed the stale rule and skill, restored edited copies, and kept user skills, GSD skills, memories and CLAUDE.md"
exit 0
