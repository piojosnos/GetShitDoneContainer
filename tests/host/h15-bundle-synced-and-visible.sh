#!/usr/bin/env bash
# H-15: the bundle is synced into state/claude, equal to the repo, and Claude lists it.
# - The rules and skills in the run folder's state/claude equal best-practices/ in the repo.
# - Claude's own /context lists the always-on rules and both skills, and not the path-scoped rules.
# - The /context probe needs no login and no network (dummy key, unreachable URL). Claude writes
#   its own state/claude/.claude.json when it runs.
# Depends on: nothing
# Needs: test sandbox running
set -u
. "$(dirname "$0")/lib.sh"
host_init
require_test_sandbox H-15 || exit 1

bundleDir=$REPO_DIR/best-practices
syncedDir=$RUN/state/claude

# --------------------------------------------------------------------------------
# Lists the bundle's skill names, one per line, in skillNameList
# --------------------------------------------------------------------------------
list_bundle_skills() {
  local skillDir skillName

  skillNameList=""

  for skillDir in "$bundleDir"/skills/*/; do
    if [ ! -d "$skillDir" ]; then
      continue
    fi

    skillName=$(basename "$skillDir")
    skillNameList="$skillNameList$skillName
"
  done
}

# --------------------------------------------------------------------------------
# Checks state/claude and what Claude lists, then prints PASS or FAIL and exits
# --------------------------------------------------------------------------------
check_and_report() {
  local rulesDiff skillDir skillName skillDiff expectedList actualList contextOutput ruleRelList ruleRel

  set --

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

  expectedList=$(printf '%s' "$skillNameList")
  actualList=$(cat "$syncedDir/.best-practices-skills" 2>/dev/null)

  if [ "$actualList" != "$expectedList" ]; then
    set -- "$@" "state/claude/.best-practices-skills lists '$(printf '%s' "$actualList" | tr '\n' ' ')'; the bundle has '$(printf '%s' "$expectedList" | tr '\n' ' ')'"
  fi

  contextOutput=$(run_timeout 60 docker exec "$CONTAINER" env ANTHROPIC_API_KEY=sk-ant-dummy ANTHROPIC_BASE_URL=http://127.0.0.1:1 claude -p /context </dev/null 2>&1)

  ruleRelList=$(cd "$bundleDir/rules" && find . -type f ! -name .DS_Store | sed 's|^\./||' | sort)

  for ruleRel in $ruleRelList; do
    if [ "$(sed -n 1p "$bundleDir/rules/$ruleRel")" = "---" ]; then
      if [[ "$contextOutput" == *"rules/$ruleRel"* ]]; then
        set -- "$@" "the path-scoped rule rules/$ruleRel is loaded at start; it should load only when a matching file is touched"
      fi
    elif [[ "$contextOutput" != *"/home/sandbox/workspace/state/claude/rules/$ruleRel"* ]]; then
      set -- "$@" "Claude does not list the always-on rule rules/$ruleRel as a memory file"
    fi
  done

  for skillName in $skillNameList; do
    if [[ "$contextOutput" != *"| $skillName | User |"* ]]; then
      set -- "$@" "Claude does not list the skill $skillName"
    fi
  done

  if [ "$#" -gt 0 ]; then
    fail H-15 "the bundle in state/claude or Claude's view of it is wrong" "$@"
    exit 1
  fi

  pass H-15 "rules and skills in state/claude equal the repo; Claude lists the always-on rules and the skills, not the path-scoped rules"
  exit 0
}

# --------------------------------------------------------------------------------
# Main / Entry Point
# --------------------------------------------------------------------------------
list_bundle_skills
check_and_report
