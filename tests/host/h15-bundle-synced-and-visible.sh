#!/usr/bin/env bash
# H-15: the bundle is synced into state/claude, equal to the repo, and Claude lists it.
# - The rules and skills in the run folder's state/claude equal best-practices/ in the repo.
# - Claude's own /context lists the always-on rules and both skills, and not the path-scoped rules.
# - The /context probe needs no login and no network (dummy key, unreachable URL). Claude writes
#   its own state/claude/.claude.json when it runs.
# - Claude runs in the project folder (docker exec -w), so its project settings are the same
#   whichever folder shells start in.
# Depends on: nothing
# Needs: test sandbox running
set -u
. "$(dirname "$0")/lib.sh"
. "$(dirname "$0")/lib-bundle.sh"
host_init

bundleDir=$REPO_DIR/best-practices
syncedDir=$RUN/state/claude

# --------------------------------------------------------------------------------
# Asks Claude for its /context and checks it lists the always-on rules and the skills
# --------------------------------------------------------------------------------
check_claude_view() {
  local contextOutput ruleRelList ruleRel skillNameList skillName

  contextOutput=$(run_timeout 60 docker exec -w "$PROJECT_DIR" "$CONTAINER" env ANTHROPIC_API_KEY=sk-ant-dummy ANTHROPIC_BASE_URL=http://127.0.0.1:1 claude -p /context </dev/null 2>&1)

  ruleRelList=$(cd "$bundleDir/rules" && find . -type f ! -name .DS_Store | sed 's|^\./||' | sort)

  for ruleRel in $ruleRelList; do
    if [ "$(sed -n 1p "$bundleDir/rules/$ruleRel")" = "---" ]; then
      if [[ "$contextOutput" == *"rules/$ruleRel"* ]]; then
        add_problem "the path-scoped rule rules/$ruleRel is loaded at start; it should load only when a matching file is touched"
      fi
    elif [[ "$contextOutput" != *"/home/sandbox/workspace/state/claude/rules/$ruleRel"* ]]; then
      add_problem "Claude does not list the always-on rule rules/$ruleRel as a memory file"
    fi
  done

  skillNameList=$(bundle_skill_names)

  for skillName in $skillNameList; do
    if [[ "$contextOutput" != *"| $skillName | User |"* ]]; then
      add_problem "Claude does not list the skill $skillName"
    fi
  done
}

# --------------------------------------------------------------------------------
# Main / Entry Point
# --------------------------------------------------------------------------------
require_no_arguments "$@" || exit 2
require_test_sandbox H-15 || exit 1
check_bundle_rules_synced "$syncedDir"
check_bundle_skills_synced "$syncedDir"
check_bundle_skill_list "$syncedDir"
check_claude_view
report_check H-15 "the bundle in state/claude or Claude's view of it is wrong" \
  "rules and skills in state/claude equal the repo; Claude lists the always-on rules and the skills, not the path-scoped rules"
