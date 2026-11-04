#!/usr/bin/env bash
# ------------------------------------------------------------------------------
# H-18: a scoped rule loads on a matching read; the managed settings hold
# ------------------------------------------------------------------------------
# Needs: test sandbox running
# Markers and edits use the run folder's clone; no other check depends on it.
# ------------------------------------------------------------------------------
set -u
. "$(dirname "$0")/lib.sh"
. "$(dirname "$0")/lib-bundle.sh"
host_init

cloneDir=$RUN/best-practices
containerRoot=/home/sandbox/workspace
containerClone=/home/sandbox/workspace/best-practices

# ------------------------------------------------------------------------------
# first_heading FILE: the first "# " heading line of FILE, without the "# "
# ------------------------------------------------------------------------------
first_heading() {
  grep -m 1 '^# ' "$1" | sed 's/^# //'
}

# ------------------------------------------------------------------------------
# run_scenario NAME SCRIPTFILE MODE: runs Claude against the fake API
# ------------------------------------------------------------------------------
# The fake API in tests/host/support scripts Claude's tool calls; no login.
# Modes: --permission-mode bypassPermissions, --permission-mode acceptEdits.
# ------------------------------------------------------------------------------
run_scenario() {
  local scenarioName=$1
  local scriptFile=$2
  local permissionMode=$3
  local runnerScript

  runnerScript="node $containerRoot/logs/fake-claude-api.js >/dev/null 2>&1 </dev/null &
serverPid=\$!
sleep 1
ANTHROPIC_BASE_URL=http://127.0.0.1:8799 ANTHROPIC_API_KEY=sk-ant-dummy claude -p go --permission-mode $permissionMode >$containerRoot/logs/h18-$scenarioName-claude.log 2>&1 </dev/null
kill \$serverPid"

  : >"$RUN/logs/h18-$scenarioName.log"
  run_timeout 120 docker exec -w "$PROJECT_DIR" "$CONTAINER" env H18_SCRIPT="$containerRoot/logs/$scriptFile" H18_LOG="$containerRoot/logs/h18-$scenarioName.log" H18_MARK_ALWAYS="$markAlways" H18_MARK_SCOPED="$markScoped" sh -c "$runnerScript" </dev/null >"$RUN/logs/h18-$scenarioName-run.log" 2>&1
}

# ------------------------------------------------------------------------------
# Picks the always-on rule and the skill to probe, and each marker
# ------------------------------------------------------------------------------
# The markers are first headings in the clone: the always-on rule, the scoped
# fixture rule and the first skill's SKILL.md.
# ------------------------------------------------------------------------------
pick_samples() {
  local ruleRelList ruleRel

  alwaysRel=""
  firstSkill=""

  if [ ! -d "$cloneDir/rules" ]; then
    fail H-18 "the run folder has no best-practices clone" "looked in $cloneDir"
    return 1
  fi

  ruleRelList=$(cd "$cloneDir/rules" && find . -type f ! -name .DS_Store | sed 's|^\./||' | sort)

  for ruleRel in $ruleRelList; do
    if [ "$(sed -n 1p "$cloneDir/rules/$ruleRel")" != "---" ]; then
      alwaysRel=$ruleRel
      break
    fi
  done

  firstSkill=$(clone_skill_names "$cloneDir" | sed -n 1p)

  if [ -z "$alwaysRel" ] || [ -z "$firstSkill" ]; then
    fail H-18 "the clone has no always-on rule or no skill to probe" "looked in $cloneDir"
    return 1
  fi

  markAlways=$(first_heading "$cloneDir/rules/$alwaysRel")
  markScoped=$(first_heading "$cloneDir/rules/sbx-fixture-shell.md")
  skillMark=$(first_heading "$cloneDir/skills/$firstSkill/SKILL.md")
}

# ------------------------------------------------------------------------------
# read_call PATH, edit_call PATH OLD NEW, write_call PATH: one tool call as JSON
# ------------------------------------------------------------------------------
read_call() {
  printf '{"name":"Read","input":{"file_path":"%s"}}' "$1"
}

edit_call() {
  printf '{"name":"Edit","input":{"file_path":"%s","old_string":"%s","new_string":"%s"}}' "$1" "$2" "$3"
}

write_call() {
  printf '{"name":"Write","input":{"file_path":"%s","content":"planted"}}' "$1"
}

# ------------------------------------------------------------------------------
# Puts the fake API, the probe files and the tool scripts in the run folder
# ------------------------------------------------------------------------------
# deny: the project edit (the control), an edit and a write through the skills
# link, then real-path edits of the clone's skill and rule, each after a Read.
# ------------------------------------------------------------------------------
prepare_files() {
  local projectRoot configRoot

  cp "$HOST_DIR/support/fake-claude-api.js" "$RUN/logs/fake-claude-api.js"
  mkdir -p "$RUN/hosttest/h18/deep"
  printf 'echo "h18 probe"\n' >"$RUN/hosttest/h18/deep/probe.sh"
  printf 'h18 control before\n' >"$RUN/hosttest/h18/control.txt"

  projectRoot=$containerRoot/hosttest
  configRoot=$containerRoot/state/claude

  printf '[%s]\n' "$(read_call "$projectRoot/h18/deep/probe.sh")" >"$RUN/logs/h18-scope.json"

  printf '[%s,%s,%s,%s,%s,%s,%s,%s,%s]\n' \
    "$(read_call "$projectRoot/h18/control.txt")" \
    "$(edit_call "$projectRoot/h18/control.txt" "before" "after")" \
    "$(read_call "$configRoot/skills/$firstSkill/SKILL.md")" \
    "$(edit_call "$configRoot/skills/$firstSkill/SKILL.md" "$skillMark" "h18 link edit")" \
    "$(write_call "$configRoot/skills/$firstSkill/h18-planted.md")" \
    "$(read_call "$containerClone/skills/$firstSkill/SKILL.md")" \
    "$(edit_call "$containerClone/skills/$firstSkill/SKILL.md" "$skillMark" "h18 real edit")" \
    "$(read_call "$containerClone/rules/$alwaysRel")" \
    "$(edit_call "$containerClone/rules/$alwaysRel" "$markAlways" "h18 bypass edit")" >"$RUN/logs/h18-deny.json"

  printf '[%s,%s]\n' \
    "$(read_call "$containerClone/rules/$alwaysRel")" \
    "$(edit_call "$containerClone/rules/$alwaysRel" "h18 bypass edit" "h18 accept edit")" >"$RUN/logs/h18-allow.json"
}

# ------------------------------------------------------------------------------
# Checks the always-on rule loaded at once, the scoped rule after the .sh read
# ------------------------------------------------------------------------------
check_scope_loading() {
  local scopeLog

  scopeLog=$RUN/logs/h18-scope.log

  if ! grep -Fq 'step=0 always=yes' "$scopeLog"; then
    add_problem "the always-on rule is not in Claude's first request, or Claude never reached the fake API; log: $(tr '\n' ' ' <"$scopeLog") run output: $(head -c 300 "$RUN/logs/h18-scope-run.log" | tr '\n' ' ')"
  fi

  if grep -Eq '^step=0 .* scoped=yes$' "$scopeLog"; then
    add_problem "the path-scoped rule loaded before any matching file was touched (sbx-fixture-shell.md is in the first request)"
  elif ! grep -Eq '^step=[1-9][0-9]* .* scoped=yes$' "$scopeLog"; then
    add_problem "the path-scoped rule never loaded after Claude read h18/deep/probe.sh; log: $(tr '\n' ' ' <"$scopeLog")"
  fi
}

# ------------------------------------------------------------------------------
# Checks the managed deny refused the edit and the write through the skills link
# ------------------------------------------------------------------------------
# The refusals count only if the edit of the project file went through. The
# clone's skill must hold the real-path text and not the link-path text.
# ------------------------------------------------------------------------------
check_deny_held() {
  local controlText

  controlText=$(cat "$RUN/hosttest/h18/control.txt" 2>/dev/null)

  if [ "$controlText" != "h18 control after" ]; then
    add_problem "the edit tool never ran, so the deny result proves nothing: h18/control.txt says '$controlText'; run output: $(head -c 300 "$RUN/logs/h18-deny-run.log" | tr '\n' ' ')"
    return
  fi

  if grep -Fq "h18 link edit" "$cloneDir/skills/$firstSkill/SKILL.md"; then
    add_problem "an edit through state/claude/skills/$firstSkill reached the clone; it should have been refused"
  fi

  if ! grep -Fq "h18 real edit" "$cloneDir/skills/$firstSkill/SKILL.md"; then
    add_problem "the edit of the clone's skill by its real path did not go through; run output: $(head -c 300 "$RUN/logs/h18-deny-run.log" | tr '\n' ' ')"
  fi

  if [ -e "$cloneDir/skills/$firstSkill/h18-planted.md" ]; then
    add_problem "a file was planted through state/claude/skills/$firstSkill/h18-planted.md; the write should have been refused"
  fi
}

# ------------------------------------------------------------------------------
# Checks the clone's rule was edited by its real path in both permission modes
# ------------------------------------------------------------------------------
# The bypassPermissions edit must be there first; the acceptEdits edit builds on
# it, so the final text shows that both went through.
# ------------------------------------------------------------------------------
check_clone_edits() {
  local ruleFile=$cloneDir/rules/$alwaysRel

  if grep -Fq "h18 accept edit" "$ruleFile"; then
    return
  fi

  if grep -Fq "h18 bypass edit" "$ruleFile"; then
    add_problem "the acceptEdits edit of the clone's rule did not go through; allow run: $(head -c 300 "$RUN/logs/h18-allow-run.log" | tr '\n' ' ') $(head -c 300 "$RUN/logs/h18-allow-claude.log" 2>/dev/null | tr '\n' ' ')"
  else
    add_problem "the bypassPermissions edit of the clone's rule by its real path did not go through; the rule still says '$(first_heading "$ruleFile")'"
  fi
}

# ------------------------------------------------------------------------------
# Main / Entry Point
# ------------------------------------------------------------------------------
require_no_arguments "$@" || exit 2
require_test_sandbox H-18 || exit 1
pick_samples || exit 1
prepare_files
run_scenario scope h18-scope.json bypassPermissions
run_scenario deny h18-deny.json bypassPermissions
run_scenario allow h18-allow.json acceptEdits
check_scope_loading
check_deny_held
check_clone_edits
report_check H-18 "path-scoped loading or the settings on the clone are wrong in the real image" \
  "the scoped rule loaded only after a .sh read; edits through ~/.claude/skills were refused; the clone's rule and skill were edited by their real path under bypassPermissions and acceptEdits"
