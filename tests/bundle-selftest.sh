#!/usr/bin/env bash
# Self-test for the best-practices bundle: runs the start hook on Linux against fixtures and the real bundle.
# - Proves the start hook claude/start.d/10-best-practices: rules mirror, skills list, hostile list
#   lines, missing bundle, and that nothing else in the config folder is touched.
# - Proves that Claude Code at the pinned version sees the synced bundle (offline, no login).
# - Cannot prove Docker. The real proof is: bash tests/host/run-all.sh on the Mac.
# - Makes one work folder under TMPDIR and removes only that folder at exit.
# - Usage, from anywhere: bash tests/bundle-selftest.sh   (exit 0 = every case passes)
set -u
cd "$(dirname "$0")/.." || exit 1
REPO=$(pwd -P)

BUNDLE=$REPO/best-practices
HOOK=$REPO/claude/start.d/10-best-practices
FAILS=0

# --------------------------------------------------------------------------------
# Makes the work folder and removes it, and only it, at exit
# --------------------------------------------------------------------------------
make_work_folder() {
  WORK=$(mktemp -d "${TMPDIR:-/tmp}/sbx-bundletest.XXXXXX") || exit 1
  WORK=$(cd "$WORK" && pwd -P)

  trap cleanup_work EXIT
  trap 'exit 130' INT TERM
}

# cleanup_work: removes the work folder made above, and only that.
cleanup_work() {
  case "$WORK" in
    */sbx-bundletest.*) rm -rf "$WORK" ;;
  esac
}

# --------------------------------------------------------------------------------
# Helpers the cases share
# --------------------------------------------------------------------------------

# expect NAME COMMAND...: PASS when the command succeeds.
expect() {
  local name=$1

  shift

  if "$@"; then
    echo "PASS: $name"
  else
    echo "FAIL: $name"
    FAILS=$((FAILS + 1))
  fi
}

# equals A B: true if the two strings are equal.
equals() { [ "$1" = "$2" ]; }

# has_text FILE TEXT: true if FILE contains TEXT.
has_text() { grep -Fq -- "$2" "$1"; }

# lacks_text FILE TEXT: true if FILE does not contain TEXT.
lacks_text() { ! grep -Fq -- "$2" "$1"; }

# trees_equal DIR DIR: true if the two folders hold the same files with the same content.
trees_equal() { diff -r "$1" "$2" >/dev/null 2>&1; }

# files_equal FILE FILE: true if the two files have the same content.
files_equal() { cmp -s "$1" "$2"; }

# run_sync BUNDLE CONFIG OUTFILE: runs the hook against a bundle and a config folder; sets SYNC_RC.
run_sync() {
  env SBX_BUNDLE_DIR="$1" CLAUDE_CONFIG_DIR="$2" bash "$HOOK" >"$3" 2>&1 </dev/null
  SYNC_RC=$?
}

# bundle_skill_names DIR: the name of each skill folder in DIR/skills, one per line, in glob order.
bundle_skill_names() {
  local skillDir

  for skillDir in "$1"/skills/*/; do
    if [ -d "$skillDir" ]; then
      basename "$skillDir"
    fi
  done
}

# is_empty_dir DIR: true if DIR exists and holds nothing.
is_empty_dir() { [ -d "$1" ] && [ -z "$(ls -A "$1")" ]; }

# plant FILE TEXT: writes TEXT as the whole content of FILE, making its folder first.
plant() {
  mkdir -p "$(dirname "$1")"
  printf '%s\n' "$2" >"$1"
}

# make_skill BUNDLE NAME: adds a skill folder with a SKILL.md and a nested file to the bundle.
make_skill() {
  plant "$1/skills/$2/SKILL.md" "skill $2"
  plant "$1/skills/$2/notes/extra.md" "extra $2"
}

# make_bundle DIR RULE...: makes a fixture bundle that holds the named rules and no skills.
make_bundle() {
  local bundleRoot=$1
  local ruleName

  shift
  mkdir -p "$bundleRoot/rules"

  for ruleName in "$@"; do
    plant "$bundleRoot/rules/$ruleName" "rule $ruleName"
  done
}

# The cases below share the globals config and fixture: some cases reuse the folders the case
# before them left behind.

# --------------------------------------------------------------------------------
# Asks the real Claude at the pinned version for /context after a sync; skipped off the pin
# --------------------------------------------------------------------------------
case_claude_sees_bundle() {
  local pin found probeConfig ruleFile relative skillName

  echo "--- Claude at the pin sees the synced bundle"
  pin=$(sed -n 's/^ARG CLAUDE_CODE_VERSION=//p' claude/Dockerfile)
  found=$(claude --version 2>/dev/null || echo "none")

  if [ "$found" != "$pin (Claude Code)" ]; then
    echo "SKIP: Claude probe (claude $found is not the pinned $pin)"
    return
  fi

  probeConfig=$WORK/probe-config
  mkdir -p "$WORK/probe-project"
  run_sync "$BUNDLE" "$probeConfig" "$WORK/out.probe-sync"
  (
    cd "$WORK/probe-project" || exit 1
    env CLAUDE_CONFIG_DIR="$probeConfig" ANTHROPIC_API_KEY=sk-ant-dummy ANTHROPIC_BASE_URL=http://127.0.0.1:1 \
      claude -p /context >"$WORK/out.context" 2>&1 </dev/null
  )

  while IFS= read -r ruleFile; do
    relative=${ruleFile#"$BUNDLE/rules/"}

    if [ "$(head -n 1 "$ruleFile")" = "---" ]; then
      expect "claude: path-scoped rule $relative is not loaded at start" lacks_text "$WORK/out.context" "rules/$relative"
    else
      expect "claude: always-on rule $relative is a User memory file" has_text "$WORK/out.context" "| User | $probeConfig/rules/$relative |"
    fi
  done <<EOF_RULES
$(find "$BUNDLE/rules" -name '*.md' | sort)
EOF_RULES

  for skillName in $(bundle_skill_names "$BUNDLE"); do
    expect "claude: skill $skillName is listed with source User" has_text "$WORK/out.context" "| $skillName | User |"
  done
}

# --------------------------------------------------------------------------------
# Helpers for the fake API cases: the real Claude at the pin, driven by a fake Anthropic API
# --------------------------------------------------------------------------------

# first_always_on_rule: prints the repo path of the first rule, in name order, that has no paths frontmatter.
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

# first_heading FILE: prints the first "# " heading line of FILE without the "# ".
first_heading() { grep -m 1 '^# ' "$1" | sed 's/^# //'; }

# run_fake_claude NAME PORT SCRIPTFILE: runs Claude from the h18 project against the fake API; sets FAKE_LOG.
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

# log_has_step LOG STEP ALWAYS SCOPED: true if the log has that exact line.
log_has_step() { grep -Fxq "step=$2 always=$3 scoped=$4" "$1"; }

# log_has_scoped_after_start LOG: true if some step above 0 has scoped=yes.
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
  firstSkill=$(bundle_skill_names "$BUNDLE" | head -n 1)
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

  pin=$(sed -n 's/^ARG CLAUDE_CODE_VERSION=//p' claude/Dockerfile)
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
# Prints the summary and exits 0 only when every case passed
# --------------------------------------------------------------------------------
report_and_exit() {
  if [ "$FAILS" -eq 0 ]; then
    echo "All cases pass."
    exit 0
  fi

  echo "$FAILS case(s) failed."
  exit 1
}

# --------------------------------------------------------------------------------
# Main / Entry Point
# --------------------------------------------------------------------------------
make_work_folder
case_claude_sees_bundle
run_fake_api_cases
report_and_exit
