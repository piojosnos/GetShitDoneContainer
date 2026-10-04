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

if [ "$FAILS" -eq 0 ]; then
  echo "All cases pass."
  exit 0
fi
echo "$FAILS case(s) failed."
exit 1
