#!/usr/bin/env bash
# Usage, from the planning checkout root: bash .planning/phases/01.4-test-suite-refactor/harness/mutate.sh   (exit 0 = "mutate: identical")
# Scratch proof tool for the test suite refactor. Proves that every deliberately broken host self-test case still fails.
# - Two mutations of tests/host/lib-report.sh, each applied in a throwaway detached worktree only:
#     add_problem  the line of add_problem that collects a message becomes a no-op colon
#     fail         fail returns 0 before it prints anything
#   Under a mutation the host checks stop failing, so exactly the cases that break a check on purpose go red.
# - Four runs in parallel: the baseline commit with each mutation (the old script) and the code branch HEAD
#   with each mutation (the new runner). Each run has its own worktree and its own TMPDIR.
# - Per mutation: the sorted "FAIL: " lines of the baseline run (RENAMED-CASES.txt applied, DROPPED-CASES.txt names
#   removed) are compared with those of the new run.
# - Each mutated run takes about five minutes: failing checks wait out their polling loops.
# Env:
#   CODE_TREE   the code worktree (default: the folder next to the planning checkout named GetShitDoneContainer-test-refactor)
#   PROVE_BASE  the baseline commit (default: origin/main when the phase was planned)
set -u
harnessDir=$(cd "$(dirname "$0")" && pwd -P) || exit 1
phaseDir=$(cd "$harnessDir/.." && pwd -P) || exit 1
planRoot=$(cd "$harnessDir" && git rev-parse --show-toplevel) || exit 1

codeTree=${CODE_TREE:-$planRoot/../GetShitDoneContainer-test-refactor}
codeTree=$(cd "$codeTree" && pwd -P) || {
  echo "mutate: no code tree at ${CODE_TREE:-$planRoot/../GetShitDoneContainer-test-refactor}"
  exit 1
}

baseCommit=${PROVE_BASE:-95c4bf534509c10bc9bf32702a37885defdb9fb3}
headCommit=$(git -C "$codeTree" rev-parse HEAD) || exit 1
renamedFile=$phaseDir/RENAMED-CASES.txt
droppedFile=$phaseDir/DROPPED-CASES.txt
mutationList="add_problem fail"
libReport=tests/host/lib-report.sh

# --------------------------------------------------------------------------------
# apply_mutation NAME TREE: edits lib-report.sh inside TREE; returns 1 when the edit changed nothing.
# --------------------------------------------------------------------------------
apply_mutation() {
  local name=$1
  local target=$2/$libReport

  cp "$target" "$target.orig" || return 1

  case "$name" in
    add_problem)
      sed 's/^  problemList+=("\$1")$/  :/' "$target.orig" >"$target" || return 1
      ;;
    fail)
      awk '{ print } $0 == "fail() {" { print "  return 0" }' "$target.orig" >"$target" || return 1
      ;;
  esac

  if cmp -s "$target.orig" "$target"; then
    echo "mutate: the $name mutation changed nothing in $target"
    return 1
  fi

  rm -f "$target.orig"
}

# --------------------------------------------------------------------------------
# run_suite SIDE MUTATION: runs the suite of one side in its worktree; writes out.SIDE.MUTATION.
# --------------------------------------------------------------------------------
run_suite() {
  local side=$1
  local name=$2
  local tree=$workDir/tree.$side.$name
  local scratchTmp=$workDir/tmp.$side.$name
  local suitePath=tests/selftest/host/run-all.sh

  if [ "$side" = "baseline" ]; then
    suitePath=tests/host-selftest.sh
  fi

  mkdir -p "$scratchTmp" || return 1
  (cd "$tree" && TMPDIR="$scratchTmp" bash "$suitePath") >"$workDir/out.$side.$name" 2>&1
}

# --------------------------------------------------------------------------------
# map_baseline: reads FAIL lines on stdin, drops the dropped cases and renames the renamed ones.
# --------------------------------------------------------------------------------
map_baseline() {
  awk -v renamed="$renamedFile" -v dropped="$droppedFile" '
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
      name = substr($0, 7)
      if (name in dropName) { next }
      if (name in newName) { $0 = "FAIL: " newName[name] }
      print
    }'
}

# --------------------------------------------------------------------------------
# Main
# --------------------------------------------------------------------------------
git -C "$codeTree" worktree prune
workDir=$(mktemp -d "${TMPDIR:-/tmp}/sbx-mutate14.XXXXXX") || exit 1
echo "mutate: work folder $workDir"

for mutationName in $mutationList; do
  for sideName in baseline head; do
    commitName=$baseCommit
    if [ "$sideName" = "head" ]; then
      commitName=$headCommit
    fi

    treePath=$workDir/tree.$sideName.$mutationName
    git -C "$codeTree" worktree add --detach "$treePath" "$commitName" >/dev/null 2>&1 || {
      echo "mutate: cannot check out $commitName"
      exit 1
    }
    apply_mutation "$mutationName" "$treePath" || exit 1
  done
done

pidList=""

for mutationName in $mutationList; do
  for sideName in baseline head; do
    run_suite "$sideName" "$mutationName" &
    pidList="$pidList $!"
  done
done

for pidName in $pidList; do
  wait "$pidName"
done

differCount=0

for mutationName in $mutationList; do
  grep '^FAIL: ' "$workDir/out.baseline.$mutationName" | map_baseline | sort >"$workDir/red.baseline.$mutationName"
  grep '^FAIL: ' "$workDir/out.head.$mutationName" | sort >"$workDir/red.head.$mutationName"

  if diff -u "$workDir/red.baseline.$mutationName" "$workDir/red.head.$mutationName" >"$workDir/red.$mutationName.diff"; then
    echo "same: mutation $mutationName ($(wc -l <"$workDir/red.head.$mutationName" | tr -d ' ') red)"
  else
    echo "DIFFERENT: mutation $mutationName"
    head -n 60 "$workDir/red.$mutationName.diff"
    differCount=$((differCount + 1))
  fi
done

for mutationName in $mutationList; do
  for sideName in baseline head; do
    git -C "$codeTree" worktree remove --force "$workDir/tree.$sideName.$mutationName"
  done
done

if [ "$differCount" -eq 0 ]; then
  case "$workDir" in */sbx-mutate14.*) rm -rf "$workDir" ;; esac
  echo "mutate: identical"
  exit 0
fi

echo "mutate: $differCount mutation(s) differ (outputs kept in $workDir)"
exit 1
