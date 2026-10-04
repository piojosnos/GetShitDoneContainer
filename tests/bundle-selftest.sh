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

WORK=$(mktemp -d "${TMPDIR:-/tmp}/sbx-bundletest.XXXXXX") || exit 1
WORK=$(cd "$WORK" && pwd -P)

# cleanup_work: removes the work folder made above, and only that.
cleanup_work() {
  case "$WORK" in
    */sbx-bundletest.*) rm -rf "$WORK" ;;
  esac
}
trap cleanup_work EXIT
trap 'exit 130' INT TERM

BUNDLE=$REPO/best-practices
HOOK=$REPO/claude/start.d/10-best-practices
FAILS=0

# --- helpers ---

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

# --- the real bundle ---

echo "--- first start from the repo bundle"
config=$WORK/real-config
mkdir -p "$config/projects/demo/memory"
echo "learned" >"$config/projects/demo/memory/note.md"
echo "mine" >"$config/CLAUDE.md"
echo "{}" >"$config/settings.json"
run_sync "$BUNDLE" "$config" "$WORK/out.real"
expect "real: the hook exits 0" equals "$SYNC_RC" "0"
expect "real: the hook is silent on success" equals "$(wc -c <"$WORK/out.real" | tr -d ' ')" "0"
expect "real: rules/ equals the bundle rules" trees_equal "$BUNDLE/rules" "$config/rules"
bundle_skill_names "$BUNDLE" >"$WORK/names.real"
expect "real: the skill list equals the bundle skill names" files_equal "$WORK/names.real" "$config/.best-practices-skills"
for skillName in $(bundle_skill_names "$BUNDLE"); do
  expect "real: skill $skillName equals the bundle copy" trees_equal "$BUNDLE/skills/$skillName" "$config/skills/$skillName"
done
expect "real: memories are untouched" equals "$(cat "$config/projects/demo/memory/note.md")" "learned"
expect "real: CLAUDE.md is untouched" equals "$(cat "$config/CLAUDE.md")" "mine"
expect "real: settings.json is untouched" equals "$(cat "$config/settings.json")" "{}"

echo "--- second run changes nothing"
run_sync "$BUNDLE" "$config" "$WORK/out.real2"
expect "real again: the hook exits 0" equals "$SYNC_RC" "0"
expect "real again: rules/ still equals the bundle rules" trees_equal "$BUNDLE/rules" "$config/rules"
expect "real again: the skill list is the same" files_equal "$WORK/names.real" "$config/.best-practices-skills"

echo "--- a hand edit and a hand-placed rule are undone"
echo "scribble" >>"$config/rules/communication.md"
echo "stray" >"$config/rules/stray.md"
run_sync "$BUNDLE" "$config" "$WORK/out.real3"
expect "edits: rules/ equals the bundle rules again" trees_equal "$BUNDLE/rules" "$config/rules"

# --- fixtures ---

echo "--- a bundle with no skills folder"
fixture=$WORK/fixture-noskills
mkdir -p "$fixture/rules"
echo "rule" >"$fixture/rules/one.md"
config=$WORK/config-noskills
run_sync "$fixture" "$config" "$WORK/out.noskills"
expect "no skills: the hook exits 0" equals "$SYNC_RC" "0"
expect "no skills: skills/ exists and is empty" is_empty_dir "$config/skills"
expect "no skills: the list file is empty" equals "$(wc -c <"$config/.best-practices-skills" | tr -d ' ')" "0"
expect "no skills: the rule is copied" files_equal "$fixture/rules/one.md" "$config/rules/one.md"

echo "--- a bundle with one skill"
fixture=$WORK/fixture-demo
mkdir -p "$fixture/rules" "$fixture/skills/demo"
echo "rule" >"$fixture/rules/one.md"
echo "skill" >"$fixture/skills/demo/SKILL.md"
config=$WORK/config-demo
mkdir -p "$config/skills/own"
echo "mine" >"$config/skills/own/SKILL.md"
run_sync "$fixture" "$config" "$WORK/out.demo"
expect "demo: the hook exits 0" equals "$SYNC_RC" "0"
expect "demo: skills/demo equals the fixture" trees_equal "$fixture/skills/demo" "$config/skills/demo"
expect "demo: the list holds exactly demo" equals "$(cat "$config/.best-practices-skills")" "demo"
expect "demo: an unlisted skill is untouched" equals "$(cat "$config/skills/own/SKILL.md")" "mine"

echo "--- a skill dropped from the bundle disappears, a clash is won by the bundle"
echo "edited" >"$config/skills/demo/SKILL.md"
rm -rf "$fixture/skills/demo"
mkdir -p "$fixture/skills/other"
echo "other" >"$fixture/skills/other/SKILL.md"
run_sync "$fixture" "$config" "$WORK/out.drop"
expect "drop: the old skill is gone" test ! -e "$config/skills/demo"
expect "drop: the new skill is there" equals "$(cat "$config/skills/other/SKILL.md")" "other"
expect "drop: the list holds exactly other" equals "$(cat "$config/.best-practices-skills")" "other"
expect "drop: an unlisted skill is untouched" equals "$(cat "$config/skills/own/SKILL.md")" "mine"
echo "clash" >"$config/skills/other/SKILL.md"
run_sync "$fixture" "$config" "$WORK/out.clash"
expect "clash: the bundle skill wins" equals "$(cat "$config/skills/other/SKILL.md")" "other"

echo "--- hostile list lines"
config=$WORK/config-hostile
mkdir -p "$config/projects/demo/memory" "$config/skills/.hidden" "$config/skills/a/b" "$config/skills/old-skill" "$config/skills/keep"
echo "learned" >"$config/projects/demo/memory/note.md"
echo "x" >"$config/skills/.hidden/file"
echo "x" >"$config/skills/a/b/file"
echo "x" >"$config/skills/old-skill/file"
echo "x" >"$config/skills/keep/file"
printf '%s\n' "../projects" ".hidden" "" "/etc" "a/b" "old-skill" >"$config/.best-practices-skills"
run_sync "$fixture" "$config" "$WORK/out.hostile"
expect "hostile: the hook exits 0" equals "$SYNC_RC" "0"
expect "hostile: memories survive" equals "$(cat "$config/projects/demo/memory/note.md")" "learned"
expect "hostile: a dot folder survives" test -f "$config/skills/.hidden/file"
expect "hostile: a nested folder survives" test -f "$config/skills/a/b/file"
expect "hostile: an unlisted skill survives" test -f "$config/skills/keep/file"
expect "hostile: the legitimately listed skill is removed" test ! -e "$config/skills/old-skill"

echo "--- a missing bundle"
config=$WORK/config-missing
mkdir -p "$config/rules"
echo "keep" >"$config/rules/keep.md"
run_sync "$WORK/no-such-bundle" "$config" "$WORK/out.missing"
expect "missing: the hook exits non-zero" test "$SYNC_RC" -ne 0
expect "missing: the output has an [sbx] ERROR line" has_text "$WORK/out.missing" "[sbx] ERROR"
expect "missing: the existing rules are untouched" equals "$(cat "$config/rules/keep.md")" "keep"

echo "--- no config folder"
env -u CLAUDE_CONFIG_DIR SBX_BUNDLE_DIR="$BUNDLE" bash "$HOOK" >"$WORK/out.noconfig" 2>&1 </dev/null
noConfigRc=$?
expect "no config: the hook exits non-zero" test "$noConfigRc" -ne 0
expect "no config: the output names CLAUDE_CONFIG_DIR" has_text "$WORK/out.noconfig" "[sbx] ERROR: CLAUDE_CONFIG_DIR is not set."

echo "--- hand edits and stray files in rules/ and in a bundle skill are undone"
fixture=$WORK/fixture-refresh
make_bundle "$fixture" one.md sub/nested.md
make_skill "$fixture" demo
config=$WORK/config-refresh
run_sync "$fixture" "$config" "$WORK/out.refresh1"
expect "refresh: a nested rule is mirrored" files_equal "$fixture/rules/sub/nested.md" "$config/rules/sub/nested.md"
echo "scribble" >>"$config/rules/one.md"
echo "scribble" >>"$config/skills/demo/SKILL.md"
echo "scribble" >"$config/skills/demo/notes/extra.md"
plant "$config/rules/stray.md" "stray"
plant "$config/rules/sub/stray-nested.md" "stray"
run_sync "$fixture" "$config" "$WORK/out.refresh2"
expect "refresh: the hook exits 0" equals "$SYNC_RC" "0"
expect "refresh: an edited rule is restored" files_equal "$fixture/rules/one.md" "$config/rules/one.md"
expect "refresh: a file placed by hand in rules/ is gone" test ! -e "$config/rules/stray.md"
expect "refresh: a file placed by hand in a rules subfolder is gone" test ! -e "$config/rules/sub/stray-nested.md"
expect "refresh: rules/ equals the bundle rules" trees_equal "$fixture/rules" "$config/rules"
expect "refresh: an edited bundle skill is restored" trees_equal "$fixture/skills/demo" "$config/skills/demo"

echo "--- a renamed rule leaves only the new name"
fixtureV1=$WORK/fixture-rename-v1
fixtureV2=$WORK/fixture-rename-v2
make_bundle "$fixtureV1" old-name.md keep.md
make_bundle "$fixtureV2" new-name.md keep.md
config=$WORK/config-rename
run_sync "$fixtureV1" "$config" "$WORK/out.rename1"
expect "rename: the old name is there after the first start" test -f "$config/rules/old-name.md"
run_sync "$fixtureV2" "$config" "$WORK/out.rename2"
expect "rename: the hook exits 0" equals "$SYNC_RC" "0"
expect "rename: the old name is gone" test ! -e "$config/rules/old-name.md"
expect "rename: the new name is there" files_equal "$fixtureV2/rules/new-name.md" "$config/rules/new-name.md"
expect "rename: rules/ equals the new bundle rules" trees_equal "$fixtureV2/rules" "$config/rules"

echo "--- a skill removed from the bundle is gone, the kept one stays listed"
fixtureV1=$WORK/fixture-removal-v1
fixtureV2=$WORK/fixture-removal-v2
make_bundle "$fixtureV1" one.md
make_skill "$fixtureV1" a-skill
make_skill "$fixtureV1" b-skill
make_bundle "$fixtureV2" one.md
make_skill "$fixtureV2" a-skill
config=$WORK/config-removal
run_sync "$fixtureV1" "$config" "$WORK/out.removal1"
expect "removal: both skills are there after the first start" test -d "$config/skills/b-skill"
run_sync "$fixtureV2" "$config" "$WORK/out.removal2"
expect "removal: the hook exits 0" equals "$SYNC_RC" "0"
expect "removal: the removed skill is gone" test ! -e "$config/skills/b-skill"
expect "removal: the kept skill equals the bundle" trees_equal "$fixtureV2/skills/a-skill" "$config/skills/a-skill"
expect "removal: the list holds exactly a-skill" equals "$(cat "$config/.best-practices-skills")" "a-skill"

echo "--- user skills, GSD skills and user files are byte-identical after a run"
fixture=$WORK/fixture-userfiles
make_bundle "$fixture" one.md
make_skill "$fixture" demo
config=$WORK/config-userfiles
saved=$WORK/saved-userfiles
plant "$config/skills/my-own/SKILL.md" "my own skill"
plant "$config/skills/my-own/notes/more.md" "more"
plant "$config/skills/gsd-sample/SKILL.md" "gsd style skill"
plant "$config/CLAUDE.md" "# my instructions"
plant "$config/settings.json" '{"theme":"dark"}'
plant "$config/.claude.json" '{"numStartups":3}'
plant "$config/.credentials.json" '{"token":"secret"}'
plant "$config/projects/p/memory/note.md" "learned note"
plant "$config/projects/p/memory/MEMORY.md" "- [note](note.md)"
cp -R "$config" "$saved"
run_sync "$fixture" "$config" "$WORK/out.userfiles"
expect "user files: the hook exits 0" equals "$SYNC_RC" "0"
expect "user files: an unlisted user skill is byte-identical" trees_equal "$saved/skills/my-own" "$config/skills/my-own"
expect "user files: a GSD-style skill is byte-identical" trees_equal "$saved/skills/gsd-sample" "$config/skills/gsd-sample"
expect "user files: CLAUDE.md is byte-identical" files_equal "$saved/CLAUDE.md" "$config/CLAUDE.md"
expect "user files: settings.json is byte-identical" files_equal "$saved/settings.json" "$config/settings.json"
expect "user files: .claude.json is byte-identical" files_equal "$saved/.claude.json" "$config/.claude.json"
expect "user files: .credentials.json is byte-identical" files_equal "$saved/.credentials.json" "$config/.credentials.json"
expect "user files: a memory note is byte-identical" files_equal "$saved/projects/p/memory/note.md" "$config/projects/p/memory/note.md"
expect "user files: MEMORY.md is byte-identical" files_equal "$saved/projects/p/memory/MEMORY.md" "$config/projects/p/memory/MEMORY.md"
run_sync "$fixture" "$config" "$WORK/out.userfiles2"
expect "user files: a second run keeps the memory note" files_equal "$saved/projects/p/memory/note.md" "$config/projects/p/memory/note.md"
expect "user files: a second run keeps the user skill" trees_equal "$saved/skills/my-own" "$config/skills/my-own"

echo "--- a user skill with a bundle skill's name is replaced and listed (no list file yet)"
fixture=$WORK/fixture-clash
make_bundle "$fixture" one.md
make_skill "$fixture" demo
config=$WORK/config-clash
plant "$config/skills/demo/SKILL.md" "the user's own demo"
plant "$config/skills/demo/private.md" "private"
run_sync "$fixture" "$config" "$WORK/out.clash2"
expect "clash: the hook exits 0 with no list file" equals "$SYNC_RC" "0"
expect "clash: the bundle skill replaced the user skill" trees_equal "$fixture/skills/demo" "$config/skills/demo"
expect "clash: nothing of the user skill is left" test ! -e "$config/skills/demo/private.md"
expect "clash: the bundle skill is listed" equals "$(cat "$config/.best-practices-skills")" "demo"

echo "--- user skills that share a prefix with a bundle skill survive"
config=$WORK/config-prefix
plant "$config/skills/dem/SKILL.md" "dem skill"
plant "$config/skills/demo-extra/SKILL.md" "demo-extra skill"
cp -R "$config/skills" "$WORK/saved-prefix"
run_sync "$fixture" "$config" "$WORK/out.prefix1"
run_sync "$fixture" "$config" "$WORK/out.prefix2"
expect "prefix: dem survives two runs" trees_equal "$WORK/saved-prefix/dem" "$config/skills/dem"
expect "prefix: demo-extra survives two runs" trees_equal "$WORK/saved-prefix/demo-extra" "$config/skills/demo-extra"
expect "prefix: the bundle skill demo is there" trees_equal "$fixture/skills/demo" "$config/skills/demo"
echo "demo" >"$WORK/names.prefix"
expect "prefix: the list holds exactly demo" files_equal "$WORK/names.prefix" "$config/.best-practices-skills"
fixtureV2=$WORK/fixture-prefix-gone
make_bundle "$fixtureV2" one.md
mkdir -p "$fixtureV2/skills"
run_sync "$fixtureV2" "$config" "$WORK/out.prefix3"
expect "prefix: removing demo from the bundle keeps dem" trees_equal "$WORK/saved-prefix/dem" "$config/skills/dem"
expect "prefix: removing demo from the bundle keeps demo-extra" trees_equal "$WORK/saved-prefix/demo-extra" "$config/skills/demo-extra"
expect "prefix: removing demo from the bundle removes demo" test ! -e "$config/skills/demo"

echo "--- an empty skills folder in the bundle empties the list and removes the listed skills"
fixture=$WORK/fixture-emptyskills
make_bundle "$fixture" one.md
make_skill "$fixture" demo
config=$WORK/config-emptyskills
plant "$config/skills/my-own/SKILL.md" "mine"
run_sync "$fixture" "$config" "$WORK/out.empty1"
expect "empty: demo is installed first" test -d "$config/skills/demo"
rm -rf "$fixture/skills/demo"
run_sync "$fixture" "$config" "$WORK/out.empty2"
expect "empty: the hook exits 0" equals "$SYNC_RC" "0"
expect "empty: demo is removed" test ! -e "$config/skills/demo"
expect "empty: the list file is empty" equals "$(wc -c <"$config/.best-practices-skills" | tr -d ' ')" "0"
expect "empty: a user skill is untouched" equals "$(cat "$config/skills/my-own/SKILL.md")" "mine"

echo "--- empty and duplicate list lines are harmless"
fixture=$WORK/fixture-duplicates
make_bundle "$fixture" one.md
make_skill "$fixture" demo
config=$WORK/config-duplicates
plant "$config/skills/demo/SKILL.md" "old demo"
plant "$config/skills/my-own/SKILL.md" "mine"
printf '%s\n' "demo" "" "demo" "" >"$config/.best-practices-skills"
run_sync "$fixture" "$config" "$WORK/out.duplicates"
expect "duplicates: the hook exits 0" equals "$SYNC_RC" "0"
expect "duplicates: the skill equals the bundle" trees_equal "$fixture/skills/demo" "$config/skills/demo"
expect "duplicates: the list holds demo once" equals "$(cat "$config/.best-practices-skills")" "demo"
expect "duplicates: a user skill is untouched" equals "$(cat "$config/skills/my-own/SKILL.md")" "mine"

echo "--- the list is in name order, whatever order the folders were made in"
fixture=$WORK/fixture-order
make_bundle "$fixture" one.md
make_skill "$fixture" b-skill
make_skill "$fixture" a-skill
make_skill "$fixture" c-skill
config=$WORK/config-order
run_sync "$fixture" "$config" "$WORK/out.order"
printf '%s\n' "a-skill" "b-skill" "c-skill" >"$WORK/names.order"
expect "order: the list reads a-skill, b-skill, c-skill" files_equal "$WORK/names.order" "$config/.best-practices-skills"

echo "--- an interrupted sync is fully repaired by the next run"
fixture=$WORK/fixture-interrupted
make_bundle "$fixture" one.md sub/nested.md
make_skill "$fixture" demo
config=$WORK/config-interrupted
plant "$config/skills/demo/SKILL.md.part" "half a file"
plant "$config/skills/my-own/SKILL.md" "mine"
printf '%s\n' "demo" >"$config/.best-practices-skills"
run_sync "$fixture" "$config" "$WORK/out.interrupted"
expect "interrupted: the hook exits 0" equals "$SYNC_RC" "0"
expect "interrupted: rules/ is back and equals the bundle" trees_equal "$fixture/rules" "$config/rules"
expect "interrupted: the partly copied skill equals the bundle" trees_equal "$fixture/skills/demo" "$config/skills/demo"
expect "interrupted: the partial file is gone" test ! -e "$config/skills/demo/SKILL.md.part"
expect "interrupted: the list holds exactly demo" equals "$(cat "$config/.best-practices-skills")" "demo"
expect "interrupted: a user skill is untouched" equals "$(cat "$config/skills/my-own/SKILL.md")" "mine"

echo "--- a config folder that cannot be written"
config=$WORK/config-locked
mkdir -p "$config"
if [ "$(id -u)" = "0" ]; then
  echo "SKIP: unwritable config folder (running as root)"
else
  chmod 555 "$config"
  run_sync "$fixture" "$config" "$WORK/out.locked"
  chmod 755 "$config"
  expect "locked: the hook exits non-zero" test "$SYNC_RC" -ne 0
  expect "locked: nothing was written" is_empty_dir "$config"
fi

# --- the real Claude at the pinned version ---

echo "--- Claude at the pin sees the synced bundle"
pin=$(sed -n 's/^ARG CLAUDE_CODE_VERSION=//p' claude/Dockerfile)
found=$(claude --version 2>/dev/null || echo "none")
if [ "$found" != "$pin (Claude Code)" ]; then
  echo "SKIP: Claude probe (claude $found is not the pinned $pin)"
else
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
fi

# --- the real Claude at the pinned version, driven by a fake Anthropic API ---

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

pin=$(sed -n 's/^ARG CLAUDE_CODE_VERSION=//p' claude/Dockerfile)
found=$(claude --version 2>/dev/null || echo "none")
if [ "$found" != "$pin (Claude Code)" ] || ! command -v node >/dev/null 2>&1; then
  echo "SKIP: fake API: a path-scoped rule loads on demand (claude $found is not the pinned $pin, or node is missing)"
  echo "SKIP: fake API: deny rules hold under bypassPermissions (claude $found is not the pinned $pin, or node is missing)"
else
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

  echo "--- fake API: a path-scoped rule loads on demand"
  printf '[{"name":"Read","input":{"file_path":"%s"}}]\n' "$H18_PROJECT/h18/deep/probe.sh" >"$WORK/h18-scope.json"
  run_fake_claude scope 8791 "$WORK/h18-scope.json"
  expect "fake api: the always-on rule is in the first request" log_has_step "$FAKE_LOG" 0 yes no
  expect "fake api: the path-scoped rule is not in the first request" lacks_text "$FAKE_LOG" "step=0 always=yes scoped=yes"
  expect "fake api: the path-scoped rule appears after the .sh file is read" log_has_scoped_after_start "$FAKE_LOG"

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
fi

if [ "$FAILS" -eq 0 ]; then
  echo "All cases pass."
  exit 0
fi
echo "$FAILS case(s) failed."
exit 1
