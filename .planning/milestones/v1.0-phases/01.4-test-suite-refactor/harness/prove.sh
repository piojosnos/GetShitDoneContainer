#!/usr/bin/env bash
# Usage, from the planning checkout root: bash .planning/phases/01.4-test-suite-refactor/harness/prove.sh   (exit 0 = every suite equals the baseline)
# Scratch proof tool for the test suite refactor. Compares the output of the four test suites in the
# code tree with the output of the same suites on the baseline commit:
#   guard       tests/guard.sh              -> tests/guard/run-all.sh              sorted case lines
#   entrypoint  tests/entrypoint-selftest.sh -> tests/selftest/entrypoint/run-all.sh  exact output
#   bundle      tests/bundle-selftest.sh    -> tests/selftest/bundle/run-all.sh    sorted case lines
#   host        tests/host-selftest.sh      -> tests/selftest/host/run-all.sh      sorted case lines
# Env:
#   CODE_TREE   the code worktree (default: the folder next to the planning checkout named GetShitDoneContainer-test-refactor)
#   PROVE_BASE  the baseline commit (default: origin/main when the phase was planned)
# Baseline outputs are cached per commit in ${TMPDIR:-/tmp}/sbx-prove14-<commit>, so only the first run pays for them.
# After side: the old script's output when the old file still exists, then the new runner's output when it exists.
# Case lines are the lines starting with "--- ", "PASS: ", "FAIL: " or "SKIP: ". On the baseline side:
#   RENAMED-CASES.txt (phase folder, lines "OLD NAME<TAB>NEW NAME", # lines ignored) maps old case names to new ones;
#   DROPPED-CASES.txt (phase folder, # lines ignored, first tab field is the case name) removes "PASS: NAME".
set -u
harnessDir=$(cd "$(dirname "$0")" && pwd -P) || exit 1
phaseDir=$(cd "$harnessDir/.." && pwd -P) || exit 1
planRoot=$(cd "$harnessDir" && git rev-parse --show-toplevel) || exit 1

codeTree=${CODE_TREE:-$planRoot/../GetShitDoneContainer-test-refactor}
codeTree=$(cd "$codeTree" && pwd -P) || {
  echo "prove: no code tree at ${CODE_TREE:-$planRoot/../GetShitDoneContainer-test-refactor}"
  exit 1
}

baseCommit=${PROVE_BASE:-95c4bf534509c10bc9bf32702a37885defdb9fb3}
cacheDir=${TMPDIR:-/tmp}/sbx-prove14-$baseCommit
suiteList="guard entrypoint bundle host"
renamedFile=$phaseDir/RENAMED-CASES.txt
droppedFile=$phaseDir/DROPPED-CASES.txt

# suite_field NAME FIELD: prints the old path, the new runner or the compare mode of a suite.
suite_field() {
  case "$1:$2" in
    guard:old) echo tests/guard.sh ;;
    guard:new) echo tests/guard/run-all.sh ;;
    guard:mode) echo sorted ;;
    entrypoint:old) echo tests/entrypoint-selftest.sh ;;
    entrypoint:new) echo tests/selftest/entrypoint/run-all.sh ;;
    entrypoint:mode) echo exact ;;
    bundle:old) echo tests/bundle-selftest.sh ;;
    bundle:new) echo tests/selftest/bundle/run-all.sh ;;
    bundle:mode) echo sorted ;;
    host:old) echo tests/host-selftest.sh ;;
    host:new) echo tests/selftest/host/run-all.sh ;;
    host:mode) echo sorted ;;
  esac
}

# case_lines FILE: prints the case lines of an output file.
case_lines() {
  grep -E '^(--- |PASS: |FAIL: |SKIP: )' "$1"
}

# map_baseline: reads case lines on stdin, drops the dropped cases and renames the renamed ones.
map_baseline() {
  awk -F'\t' -v renamed="$renamedFile" -v dropped="$droppedFile" '
    BEGIN {
      while ((getline line < renamed) > 0) {
        if (line == "" || line ~ /^#/) { continue }
        split(line, field, "\t")
        newName[field[1]] = field[2]
      }
      while ((getline line < dropped) > 0) {
        if (line == "" || line ~ /^#/) { continue }
        split(line, field, "\t")
        dropName[field[1]] = 1
      }
    }
    {
      if (match($0, /^(PASS|FAIL|SKIP): /)) {
        kind = substr($0, 1, RLENGTH)
        name = substr($0, RLENGTH + 1)
        if (kind == "PASS: " && (name in dropName)) { next }
        if (name in newName) { $0 = kind newName[name] }
      }
      print
    }'
}

# build_baseline: runs the old scripts on a detached worktree of the baseline commit; caches the outputs.
build_baseline() {
  local name
  local oldPath

  echo "prove: building the baseline for $baseCommit (first run only)"
  case "$cacheDir" in */sbx-prove14-*) rm -rf "$cacheDir" ;; esac
  git -C "$codeTree" worktree prune
  mkdir -p "$cacheDir" || exit 1
  git -C "$codeTree" worktree add --detach "$cacheDir/tree" "$baseCommit" >/dev/null 2>&1 || {
    echo "prove: cannot check out $baseCommit"
    exit 1
  }

  for name in $suiteList; do
    oldPath=$(suite_field "$name" old)
    (cd "$cacheDir/tree" && bash "$oldPath") >"$cacheDir/before.$name" 2>&1
  done

  git -C "$codeTree" worktree remove --force "$cacheDir/tree"
  : >"$cacheDir/before.done"
}

# collect_after NAME: writes after.NAME and the marker after.NAME.ran (old, new, both or none).
collect_after() {
  local name=$1
  local oldPath
  local newPath
  local ran=""

  oldPath=$(suite_field "$name" old)
  newPath=$(suite_field "$name" new)
  : >"$afterDir/after.$name"

  if [ -f "$codeTree/$oldPath" ]; then
    (cd "$codeTree" && bash "$oldPath") >>"$afterDir/after.$name" 2>&1
    ran="old"
  fi

  if [ -f "$codeTree/$newPath" ]; then
    (cd "$codeTree" && bash "$newPath") >>"$afterDir/after.$name" 2>&1
    ran="$ran${ran:+ }new"
  fi

  echo "${ran:-none}" >"$afterDir/after.$name.ran"
}

# compare_suite NAME: prints "same:" or "DIFFERENT:" for one suite; returns 1 when it differs.
compare_suite() {
  local name=$1
  local ran
  local mode
  local before=$cacheDir/before.$name
  local after=$afterDir/after.$name
  local diffFile=$afterDir/$name.diff
  local lastBefore
  local lastAfter

  ran=$(cat "$after.ran")
  mode=$(suite_field "$name" mode)

  if [ "$ran" = "none" ]; then
    echo "DIFFERENT: $name (neither the old script nor the new runner exists in the code tree)"
    return 1
  fi

  case "$ran" in
    *old*) mode=sorted ;;
  esac

  if [ "$mode" = "exact" ]; then
    diff -u "$before" "$after" >"$diffFile"
  else
    case_lines "$before" | map_baseline | sort >"$afterDir/$name.before.sorted"
    case_lines "$after" | sort >"$afterDir/$name.after.sorted"
    diff -u "$afterDir/$name.before.sorted" "$afterDir/$name.after.sorted" >"$diffFile"
  fi

  if [ $? -ne 0 ]; then
    echo "DIFFERENT: $name"
    head -n 60 "$diffFile"
    echo "full diff: $diffFile"
    return 1
  fi

  if [ "$mode" = "sorted" ]; then
    case "$ran" in
      new)
        lastBefore=$(tail -n 1 "$before")
        lastAfter=$(tail -n 1 "$after")

        if [ "$lastBefore" != "$lastAfter" ]; then
          echo "DIFFERENT: $name (last line: '$lastAfter' instead of '$lastBefore')"
          return 1
        fi
        ;;
    esac
  fi

  echo "same: $name ($(grep -c '^PASS: ' "$after") PASS)"
}

# --------------------------------------------------------------------------------
# Main
# --------------------------------------------------------------------------------
if [ ! -f "$cacheDir/before.done" ]; then
  build_baseline
fi

afterDir=$(mktemp -d "${TMPDIR:-/tmp}/sbx-prove14-after.XXXXXX") || exit 1
differCount=0

for suiteName in $suiteList; do
  collect_after "$suiteName"
  compare_suite "$suiteName" || differCount=$((differCount + 1))
done

if [ "$differCount" -eq 0 ]; then
  case "$afterDir" in */sbx-prove14-after.*) rm -rf "$afterDir" ;; esac
  echo "prove: identical"
  exit 0
fi

echo "prove: $differCount suite(s) differ"
exit 1
