#!/usr/bin/env bash
# H-18: in the real image, a path-scoped rule loads only after Claude reads a matching file, and the managed deny refuses edits to synced files under bypassPermissions.
# - A fake Anthropic API in tests/host/support scripts Claude's tool calls, so no login and no network
#   are needed. The scripts and assertions are the same as tests/selftest/bundle/fake-api.sh.
# - It is tied to the wire format of the pinned Claude. After a pin bump, run
#   bash tests/selftest/bundle/run-all.sh in the dev sandbox first.
# - Claude runs in the project folder (docker exec -w), so its project settings are the same
#   whichever folder shells start in.
# - No other check depends on it: remove this script and its entry in run-all.sh to drop it.
# Depends on: nothing
# Needs: test sandbox running
set -u
. "$(dirname "$0")/lib.sh"
host_init

bundleDir=$REPO_DIR/best-practices
syncedDir=$RUN/state/claude
containerRoot=/home/sandbox/workspace

# --------------------------------------------------------------------------------
# first_heading FILE: prints the first "# " heading line of FILE without the "# ".
# --------------------------------------------------------------------------------
first_heading() {
  grep -m 1 '^# ' "$1" | sed 's/^# //'
}

# --------------------------------------------------------------------------------
# run_scenario NAME SCRIPTFILE: runs Claude against the fake API inside the test container.
# --------------------------------------------------------------------------------
run_scenario() {
  local scenarioName=$1
  local scriptFile=$2
  local runnerScript

  runnerScript="node $containerRoot/logs/fake-claude-api.js >/dev/null 2>&1 </dev/null &
serverPid=\$!
sleep 1
ANTHROPIC_BASE_URL=http://127.0.0.1:8799 ANTHROPIC_API_KEY=sk-ant-dummy claude -p go --permission-mode bypassPermissions >$containerRoot/logs/h18-$scenarioName-claude.log 2>&1 </dev/null
kill \$serverPid"

  : >"$RUN/logs/h18-$scenarioName.log"
  run_timeout 120 docker exec -w "$PROJECT_DIR" "$CONTAINER" env H18_SCRIPT="$containerRoot/logs/$scriptFile" H18_LOG="$containerRoot/logs/h18-$scenarioName.log" H18_MARK_ALWAYS="$markAlways" H18_MARK_SCOPED="$markScoped" sh -c "$runnerScript" </dev/null >"$RUN/logs/h18-$scenarioName-run.log" 2>&1
}

# --------------------------------------------------------------------------------
# Picks the always-on rule and the skill to probe, and each rule's marker heading
# --------------------------------------------------------------------------------
pick_samples() {
  local ruleRelList ruleRel skillDir

  alwaysRel=""
  ruleRelList=$(cd "$bundleDir/rules" && find . -type f ! -name .DS_Store | sed 's|^\./||' | sort)

  for ruleRel in $ruleRelList; do
    if [ "$(sed -n 1p "$bundleDir/rules/$ruleRel")" != "---" ]; then
      alwaysRel=$ruleRel
      break
    fi
  done

  firstSkill=""

  for skillDir in "$bundleDir"/skills/*/; do
    if [ -d "$skillDir" ]; then
      firstSkill=$(basename "$skillDir")
      break
    fi
  done

  markAlways=$(first_heading "$bundleDir/rules/$alwaysRel")
  markScoped=$(first_heading "$bundleDir/rules/shell.md")
}

# --------------------------------------------------------------------------------
# Puts the fake API, the probe files and the two tool call scripts in the run folder
# --------------------------------------------------------------------------------
prepare_files() {
  local projectRoot configRoot

  cp "$HOST_DIR/support/fake-claude-api.js" "$RUN/logs/fake-claude-api.js"
  mkdir -p "$RUN/hosttest/h18/deep"
  printf 'echo "h18 probe"\n' >"$RUN/hosttest/h18/deep/probe.sh"
  printf 'h18 control before\n' >"$RUN/hosttest/h18/control.txt"

  projectRoot=$containerRoot/hosttest
  configRoot=$containerRoot/state/claude

  printf '[{"name":"Read","input":{"file_path":"%s/h18/deep/probe.sh"}}]\n' "$projectRoot" >"$RUN/logs/h18-scope.json"
  printf '[{"name":"Read","input":{"file_path":"%s/h18/control.txt"}},{"name":"Edit","input":{"file_path":"%s/h18/control.txt","old_string":"before","new_string":"after"}},{"name":"Read","input":{"file_path":"%s/rules/%s"}},{"name":"Edit","input":{"file_path":"%s/rules/%s","old_string":"%s","new_string":"scribble"}},{"name":"Write","input":{"file_path":"%s/rules/h18-planted.md","content":"planted"}},{"name":"Write","input":{"file_path":"%s/skills/%s/h18-planted.md","content":"planted"}}]\n' \
    "$projectRoot" "$projectRoot" "$configRoot" "$alwaysRel" "$configRoot" "$alwaysRel" "$markAlways" "$configRoot" "$configRoot" "$firstSkill" >"$RUN/logs/h18-deny.json"
}

# --------------------------------------------------------------------------------
# Checks the always-on rule loaded at once and the path-scoped rule only after the .sh read
# --------------------------------------------------------------------------------
check_scope_loading() {
  local scopeLog

  scopeLog=$RUN/logs/h18-scope.log

  if ! grep -Fq 'step=0 always=yes' "$scopeLog"; then
    add_problem "the always-on rule is not in Claude's first request, or Claude never reached the fake API; log: $(tr '\n' ' ' <"$scopeLog") run output: $(head -c 300 "$RUN/logs/h18-scope-run.log" | tr '\n' ' ')"
  fi

  if grep -Eq '^step=0 .* scoped=yes$' "$scopeLog"; then
    add_problem "the path-scoped rule loaded before any matching file was touched (shell.md is in the first request)"
  elif ! grep -Eq '^step=[1-9][0-9]* .* scoped=yes$' "$scopeLog"; then
    add_problem "the path-scoped rule never loaded after Claude read h18/deep/probe.sh; log: $(tr '\n' ' ' <"$scopeLog")"
  fi
}

# --------------------------------------------------------------------------------
# Checks the managed deny refused edits and writes to synced files; counts only if the project edit went through
# --------------------------------------------------------------------------------
check_deny_held() {
  local controlText

  controlText=$(cat "$RUN/hosttest/h18/control.txt" 2>/dev/null)

  if [ "$controlText" != "h18 control after" ]; then
    add_problem "the edit tool never ran, so the deny result proves nothing: h18/control.txt says '$controlText'; run output: $(head -c 300 "$RUN/logs/h18-deny-run.log" | tr '\n' ' ')"
    return
  fi

  if ! cmp -s "$bundleDir/rules/$alwaysRel" "$syncedDir/rules/$alwaysRel"; then
    add_problem "the synced rule state/claude/rules/$alwaysRel was changed by an edit that should have been refused"
  fi

  if [ -e "$syncedDir/rules/h18-planted.md" ]; then
    add_problem "a file was planted in state/claude/rules/h18-planted.md; the write should have been refused"
  fi

  if [ -e "$syncedDir/skills/$firstSkill/h18-planted.md" ]; then
    add_problem "a file was planted in state/claude/skills/$firstSkill/h18-planted.md; the write should have been refused"
  fi
}

# --------------------------------------------------------------------------------
# Main / Entry Point
# --------------------------------------------------------------------------------
require_no_arguments "$@" || exit 2
require_test_sandbox H-18 || exit 1
pick_samples
prepare_files
run_scenario scope h18-scope.json
run_scenario deny h18-deny.json
check_scope_loading
check_deny_held
report_check H-18 "path-scoped loading or the managed deny is wrong in the real image" \
  "shell.md loaded only after a .sh read; edits and writes to synced files were refused under bypassPermissions; the project edit went through"
