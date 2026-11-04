#!/usr/bin/env bash
# ------------------------------------------------------------------------------
# H-15: the clone is linked into state/claude and Claude lists it
# ------------------------------------------------------------------------------
# Needs: test sandbox running
# The run folder's best-practices clone stands in for the real bundle repo.
# ------------------------------------------------------------------------------
set -u
. "$(dirname "$0")/lib.sh"
. "$(dirname "$0")/lib-bundle.sh"
host_init

cloneDir=$RUN/best-practices
configDir=$RUN/state/claude

# ------------------------------------------------------------------------------
# Asks Claude for its /context; checks it lists the always-on rules and skills
# ------------------------------------------------------------------------------
# No login or network is needed (dummy key, unreachable URL). The scoped rules
# must not be listed; Claude lists a linked rule by its resolved clone path.
# ------------------------------------------------------------------------------
check_claude_view() {
  local contextOutput ruleRelList ruleRel skillNameList skillName

  contextOutput=$(run_timeout 60 docker exec -w "$PROJECT_DIR" "$CONTAINER" env ANTHROPIC_API_KEY=sk-ant-dummy ANTHROPIC_BASE_URL=http://127.0.0.1:1 claude -p /context </dev/null 2>&1)

  ruleRelList=$(cd "$cloneDir/rules" && find . -type f ! -name .DS_Store | sed 's|^\./||' | sort)

  for ruleRel in $ruleRelList; do
    if [ "$(sed -n 1p "$cloneDir/rules/$ruleRel")" = "---" ]; then
      if [[ "$contextOutput" == *"rules/$ruleRel"* ]]; then
        add_problem "the path-scoped rule rules/$ruleRel is loaded at start; it should load only when a matching file is touched"
      fi
    elif [[ "$contextOutput" != *"/home/sandbox/workspace/best-practices/rules/$ruleRel"* ]]; then
      add_problem "Claude does not list the always-on rule /home/sandbox/workspace/best-practices/rules/$ruleRel as a memory file"
    fi
  done

  skillNameList=$(clone_skill_names "$cloneDir")

  for skillName in $skillNameList; do
    if [[ "$contextOutput" != *"| $skillName | User |"* ]]; then
      add_problem "Claude does not list the skill $skillName"
    fi
  done
}

# ------------------------------------------------------------------------------
# Checks the container reads the clone's rule through ~/.claude/rules
# ------------------------------------------------------------------------------
check_container_view() {
  local containerText macText

  containerText=$(in_container cat /home/sandbox/workspace/state/claude/rules/sbx-fixture-always.md)
  macText=$(cat "$cloneDir/rules/sbx-fixture-always.md" 2>&1)

  if [ "$containerText" != "$macText" ]; then
    add_problem "the container reads rules/sbx-fixture-always.md as '$(first_lines "$containerText")'; the clone holds '$(first_lines "$macText")'"
  fi
}

# ------------------------------------------------------------------------------
# Main / Entry Point
# ------------------------------------------------------------------------------
require_no_arguments "$@" || exit 2
require_test_sandbox H-15 || exit 1
check_bundle_links "$configDir" "$cloneDir"
check_claude_view
check_container_view
report_check H-15 "the clone links or Claude's view of the clone are wrong" \
  "state/claude links into the clone; Claude lists its always-on rules by their clone path and its skills, not its scoped rule; the container reads the clone through ~/.claude/rules"
