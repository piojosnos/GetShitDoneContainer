#!/usr/bin/env bash
# Shared by the bundle self-test groups: where the bundle and the start hook are, how a group starts, and the fixture helpers several groups use.
# - Sourced by the groups, never run directly.
# - Defines functions only.
# - Loads lib-expect.sh and the host tests' lib-bundle.sh (for bundle_skill_names).
# - Linux only, in the dev sandbox.

. "$(dirname "${BASH_SOURCE[0]}")/../lib-expect.sh"
. "$(dirname "${BASH_SOURCE[0]}")/../../host/lib-bundle.sh"

# --------------------------------------------------------------------------------
# start_group: enters the repository root, sets BUNDLE and HOOK, and makes the work folder; returns 1 on failure.
# --------------------------------------------------------------------------------
start_group() {
  enter_repo_root || return 1

  BUNDLE=$REPO/best-practices
  HOOK=$REPO/claude/start.d/10-best-practices

  make_work_folder bundletest || return 1
}

# --------------------------------------------------------------------------------
# trees_equal DIR DIR: true if the two folders hold the same files with the same content.
# --------------------------------------------------------------------------------
trees_equal() { diff -r "$1" "$2" >/dev/null 2>&1; }

# --------------------------------------------------------------------------------
# files_equal FILE FILE: true if the two files have the same content.
# --------------------------------------------------------------------------------
files_equal() { cmp -s "$1" "$2"; }

# --------------------------------------------------------------------------------
# run_sync BUNDLE CONFIG OUTFILE: runs the hook against a bundle and a config folder; sets SYNC_RC.
# --------------------------------------------------------------------------------
run_sync() {
  env SBX_BUNDLE_DIR="$1" CLAUDE_CONFIG_DIR="$2" bash "$HOOK" >"$3" 2>&1 </dev/null
  SYNC_RC=$?
}

# --------------------------------------------------------------------------------
# is_empty_dir DIR: true if DIR exists and holds nothing.
# --------------------------------------------------------------------------------
is_empty_dir() { [ -d "$1" ] && [ -z "$(ls -A "$1")" ]; }

# --------------------------------------------------------------------------------
# plant FILE TEXT: writes TEXT as the whole content of FILE, making its folder first.
# --------------------------------------------------------------------------------
plant() {
  mkdir -p "$(dirname "$1")"
  printf '%s\n' "$2" >"$1"
}

# --------------------------------------------------------------------------------
# make_skill BUNDLE NAME: adds a skill folder with a SKILL.md and a nested file to the bundle.
# --------------------------------------------------------------------------------
make_skill() {
  plant "$1/skills/$2/SKILL.md" "skill $2"
  plant "$1/skills/$2/notes/extra.md" "extra $2"
}

# --------------------------------------------------------------------------------
# make_bundle DIR RULE...: makes a fixture bundle that holds the named rules and no skills.
# --------------------------------------------------------------------------------
make_bundle() {
  local bundleRoot=$1
  local ruleName

  shift
  mkdir -p "$bundleRoot/rules"

  for ruleName in "$@"; do
    plant "$bundleRoot/rules/$ruleName" "rule $ruleName"
  done
}
