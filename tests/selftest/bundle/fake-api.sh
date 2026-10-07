#!/usr/bin/env bash
# Self-test of the real Claude at the pin against the scripted fake Anthropic API: a path-scoped rule loads on demand, and the deny rules hold under bypassPermissions.
# - Runs node with tests/host/support/fake-claude-api.js on 127.0.0.1, ports 8791 and 8792.
# - Prints two SKIP lines when claude is not at the pin or node is missing.
# - prepare_fake_api sets the variables the two cases share, so they stay in this file.
# - Run by run-all.sh; runs alone too.
# - Makes one work folder under TMPDIR and removes only that folder at exit.
# - Usage, from anywhere: bash tests/selftest/bundle/fake-api.sh   (exit 0 = every case passes)
set -u
. "$(dirname "$0")/lib.sh"

# --------------------------------------------------------------------------------
# first_always_on_rule: prints the repo path of the first rule, in name order, that has no paths frontmatter.
# --------------------------------------------------------------------------------
first_always_on_rule() {
  local ruleFile

  while IFS= read -r ruleFile; do
    if [ "$(head -n 1 "$ruleFile")" != "---" ]; then
      echo "$ruleFile"
      return 0
    fi
  done <<EOF_FIRST
$(find "$BUNDLE/rules" -name '*.md' | sort)
EOF_FIRST

  return 1
}

# --------------------------------------------------------------------------------
# first_heading FILE: prints the first "# " heading line of FILE without the "# ".
# --------------------------------------------------------------------------------
first_heading() { grep -m 1 '^# ' "$1" | sed 's/^# //'; }

# --------------------------------------------------------------------------------
# run_fake_claude NAME PORT SCRIPTFILE: runs Claude from the h18 project against the fake API; sets FAKE_LOG.
# --------------------------------------------------------------------------------
run_fake_claude() {
  local scenarioName=$1
  local fakePort=$2
  local scriptFile=$3
  local serverPid

  FAKE_LOG=$WORK/h18-$scenarioName.log
  : >"$FAKE_LOG"
  env H18_PORT="$fakePort" H18_SCRIPT="$scriptFile" H18_LOG="$FAKE_LOG" \
    H18_MARK_ALWAYS="$H18_MARK_ALWAYS" H18_MARK_SCOPED="$H18_MARK_SCOPED" \
    node "$REPO/tests/host/support/fake-claude-api.js" >"$WORK/h18-$scenarioName-server.out" 2>&1 </dev/null &
  serverPid=$!
  sleep 1
  (
    cd "$WORK/h18-project" || exit 1
    env CLAUDE_CONFIG_DIR="$H18_CONFIG" ANTHROPIC_BASE_URL="http://127.0.0.1:$fakePort" ANTHROPIC_API_KEY=sk-ant-dummy \
      timeout 90 claude -p go --permission-mode bypassPermissions >"$WORK/h18-$scenarioName-claude.out" 2>&1 </dev/null
  )
  kill "$serverPid" 2>/dev/null
  wait "$serverPid" 2>/dev/null
}

# --------------------------------------------------------------------------------
# log_has_step LOG STEP ALWAYS SCOPED: true if the log has that exact line.
# --------------------------------------------------------------------------------
log_has_step() { grep -Fxq "step=$2 always=$3 scoped=$4" "$1"; }

# --------------------------------------------------------------------------------
# log_has_scoped_after_start LOG: true if some step above 0 has scoped=yes.
# --------------------------------------------------------------------------------
log_has_scoped_after_start() { grep -Eq '^step=[1-9][0-9]* always=[a-z]+ scoped=yes$' "$1"; }

# --------------------------------------------------------------------------------
# Syncs the repo bundle for the fake API cases and picks the rules and skill they use
# --------------------------------------------------------------------------------
prepare_fake_api() {
  H18_CONFIG=$WORK/h18-config
  H18_PROJECT=$WORK/h18-project
  run_sync "$BUNDLE" "$H18_CONFIG" "$WORK/out.h18-sync"
  alwaysRule=$(first_always_on_rule)
  alwaysRuleName=${alwaysRule#"$BUNDLE/rules/"}
  H18_MARK_ALWAYS=$(first_heading "$alwaysRule")
  H18_MARK_SCOPED=$(first_heading "$BUNDLE/rules/shell.md")
  firstSkill=$(bundle_skill_names | head -n 1)
  plant "$H18_PROJECT/h18/deep/probe.sh" 'echo probe'
  plant "$H18_PROJECT/h18/control.txt" "h18 control before"
}

# --------------------------------------------------------------------------------
# Has Claude read a .sh file and checks the path-scoped rule loads only then
# --------------------------------------------------------------------------------
case_fake_api_scope() {
  echo "--- fake API: a path-scoped rule loads on demand"
  printf '[{"name":"Read","input":{"file_path":"%s"}}]\n' "$H18_PROJECT/h18/deep/probe.sh" >"$WORK/h18-scope.json"
  run_fake_claude scope 8791 "$WORK/h18-scope.json"
  expect "fake api: the always-on rule is in the first request" log_has_step "$FAKE_LOG" 0 yes no
  expect "fake api: the path-scoped rule is not in the first request" lacks_text "$FAKE_LOG" "step=0 always=yes scoped=yes"
  expect "fake api: the path-scoped rule appears after the .sh file is read" log_has_scoped_after_start "$FAKE_LOG"
}

# --------------------------------------------------------------------------------
# Has Claude edit a project file and the synced bundle under the managed deny rules
# --------------------------------------------------------------------------------
case_fake_api_deny() {
  local deleteMark syncedRule

  echo "--- fake API: deny rules hold under bypassPermissions"
  deleteMark=$(printf '\001')
  sed "s${deleteMark}//home/sandbox/workspace/state/claude${deleteMark}/$H18_CONFIG${deleteMark}g" claude/managed-settings.json >"$H18_CONFIG/settings.json"
  syncedRule=$H18_CONFIG/rules/$alwaysRuleName
  printf '[{"name":"Read","input":{"file_path":"%s"}},{"name":"Edit","input":{"file_path":"%s","old_string":"before","new_string":"after"}},{"name":"Read","input":{"file_path":"%s"}},{"name":"Edit","input":{"file_path":"%s","old_string":"%s","new_string":"scribble"}},{"name":"Write","input":{"file_path":"%s","content":"planted"}},{"name":"Write","input":{"file_path":"%s","content":"planted"}}]\n' \
    "$H18_PROJECT/h18/control.txt" "$H18_PROJECT/h18/control.txt" "$syncedRule" "$syncedRule" "$H18_MARK_ALWAYS" \
    "$H18_CONFIG/rules/h18-planted.md" "$H18_CONFIG/skills/$firstSkill/h18-planted.md" >"$WORK/h18-deny.json"
  run_fake_claude deny 8792 "$WORK/h18-deny.json"
  expect "fake api: the project file was edited" equals "$(cat "$H18_PROJECT/h18/control.txt")" "h18 control after"
  expect "fake api: the synced rule is unchanged" files_equal "$alwaysRule" "$syncedRule"
  expect "fake api: no file was planted in rules/" test ! -e "$H18_CONFIG/rules/h18-planted.md"
  expect "fake api: no file was planted in a bundle skill" test ! -e "$H18_CONFIG/skills/$firstSkill/h18-planted.md"
}

# --------------------------------------------------------------------------------
# Runs the fake API cases when Claude is at the pin and node is there; else prints SKIP lines
# --------------------------------------------------------------------------------
run_fake_api_cases() {
  local pin found

  pin=$(claude_pin)
  found=$(claude --version 2>/dev/null || echo "none")

  if [ "$found" != "$pin (Claude Code)" ] || ! command -v node >/dev/null 2>&1; then
    echo "SKIP: fake API: a path-scoped rule loads on demand (claude $found is not the pinned $pin, or node is missing)"
    echo "SKIP: fake API: deny rules hold under bypassPermissions (claude $found is not the pinned $pin, or node is missing)"
    return
  fi

  prepare_fake_api
  case_fake_api_scope
  case_fake_api_deny
}

# --------------------------------------------------------------------------------
# Main / Entry Point
# --------------------------------------------------------------------------------
require_no_arguments "$@" || exit 2
start_group || exit 1
run_fake_api_cases
finish_cases
